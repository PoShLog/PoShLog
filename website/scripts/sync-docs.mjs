// Copies the Markdown from docs/ and the first-party extension READMEs into the Starlight content folder (ADR 0022).
// docs/ stays the source: this script adds front matter, turns links between Markdown files into site links, points
// links to anything else in the repository at GitHub and fails the build on a link to a missing file.
import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const website = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repo = path.resolve(website, '..');
const contentRoot = path.join(website, 'src', 'content', 'docs');
const publicRoot = path.join(website, 'public');
const generatedRoot = path.join(website, 'src', 'generated');
const github = 'https://github.com/PoShLog/PoShLog';
const branch = 'master';
const base = (process.env.SITE_BASE ?? '/').replace(/\/?$/, '/');

// Repository file (posix, relative to the repo) → site slug, for every page the site gets.
const pages = new Map();
for (const file of walk(path.join(repo, 'docs')).filter((f) => f.endsWith('.md'))) {
	pages.set(toPosix(path.relative(repo, file)), slugFor(path.relative(path.join(repo, 'docs'), file)));
}
for (const dir of fs.readdirSync(path.join(repo, 'extensions'))) {
	const readme = path.join(repo, 'extensions', dir, 'README.md');
	if (fs.existsSync(readme)) {
		pages.set(`extensions/${dir}/README.md`, `extensions/${slugify(dir)}`);
	}
}
pages.set('CHANGELOG.md', 'changelog');

const errors = [];
fs.rmSync(contentRoot, { recursive: true, force: true });
// The landing page is the one page that exists only on the site.
fs.mkdirSync(contentRoot, { recursive: true });
fs.copyFileSync(path.join(website, "src", "landing.mdx"), path.join(contentRoot, "index.mdx"));
for (const [source, slug] of pages) {
	const text = fs.readFileSync(path.join(repo, source), 'utf8').replace(/\r\n/g, '\n');
	const target = path.join(contentRoot, ...(slug === '' ? ['index'] : slug.split('/'))) + '.md';
	fs.mkdirSync(path.dirname(target), { recursive: true });
	fs.writeFileSync(target, convert(source, text, slug));
}
for (const folder of ['assets', 'images']) {
	fs.cpSync(path.join(repo, 'docs', folder), path.join(publicRoot, folder), { recursive: true });
}
fs.copyFileSync(path.join(repo, 'docs', 'assets', 'icon.png'), path.join(publicRoot, 'favicon.png'));
fs.mkdirSync(generatedRoot, { recursive: true });
fs.copyFileSync(path.join(repo, 'docs', 'assets', 'icon.png'), path.join(generatedRoot, 'icon.png'));
writeBuildInfo();

if (errors.length) {
	console.error(`sync-docs: ${errors.length} broken link(s):\n  ${errors.join('\n  ')}`);
	process.exit(1);
}
console.log(`sync-docs: ${pages.size} pages from docs/ and extensions/.`);

function convert(source, text, slug) {
	const heading = text.match(/^# (.+)$/m);
	const title = heading ? heading[1].trim() : path.basename(source, '.md');
	let body = heading ? text.replace(heading[0], '').replace(/^\s+/, '') : text;
	body = convertAlerts(body);
	body = rewriteLinks(source, body);
	const frontMatter = [
		'---',
		`title: ${JSON.stringify(title.replace(/`/g, ''))}`,
		`slug: ${JSON.stringify(slug)}`,
		`editUrl: ${JSON.stringify(`${github}/edit/${branch}/${source}`)}`,
		'---',
		'',
	];
	return frontMatter.join('\n') + body;
}

// GitHub alerts ("> [!NOTE]") become Starlight asides.
function convertAlerts(body) {
	const kinds = { NOTE: 'note', TIP: 'tip', IMPORTANT: 'note', WARNING: 'caution', CAUTION: 'danger' };
	return body.replace(/^> \[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\n((?:>.*\n?)*)/gm, (_, kind, quoted) => {
		const inner = quoted.replace(/^> ?/gm, '').trimEnd();
		return `:::${kinds[kind]}\n${inner}\n:::\n`;
	});
}

// Rewrites Markdown links and images outside code blocks; inline code is kept as it is, also inside a link label.
function rewriteLinks(source, body) {
	const parts = body.split(/(^```[\s\S]*?^```$)/m);
	const link = /(!?)\[((?:[^\[\]`]|`[^`\n]*`)*)\]\(([^)\s]+)\)|`[^`\n]*`/g;
	return parts
		.map((part, i) => (i % 2 === 1 ? part : part.replace(link, (match, bang, label, url) => {
			if (url === undefined) {
				return match;
			}
			const resolved = resolveLink(source, url, bang === '!');
			return resolved === url ? match : `${bang}[${label}](${resolved})`;
		})))
		.join('');
}

function resolveLink(source, url, isImage) {
	if (/^([a-z]+:|#|\/\/)/i.test(url)) {
		return url;
	}
	const [target, hash] = url.split('#');
	const repoPath = toPosix(path.normalize(path.join(path.dirname(source), decodeURI(target))));
	const anchor = hash ? `#${hash.toLowerCase()}` : '';
	if ((repoPath.startsWith('docs/assets/') || repoPath.startsWith('docs/images/')) && fs.existsSync(path.join(repo, repoPath))) {
		return `${base}${repoPath.slice('docs/'.length)}`;
	}
	if (pages.has(repoPath)) {
		const slug = pages.get(repoPath);
		return `${base}${slug ? `${slug}/` : ''}${anchor}`;
	}
	if (!fs.existsSync(path.join(repo, repoPath))) {
		errors.push(`${source}: ${url}`);
		return url;
	}
	const isDirectory = fs.statSync(path.join(repo, repoPath)).isDirectory();
	return `${github}/${isImage ? 'raw' : isDirectory ? 'tree' : 'blob'}/${branch}/${repoPath}${anchor}`;
}

function writeBuildInfo() {
	const manifest = fs.readFileSync(path.join(repo, 'src', 'PoShLog.psd1'), 'utf8');
	const version = manifest.match(/ModuleVersion\s*=\s*'([^']+)'/)[1];
	const prerelease = manifest.match(/^\s*Prerelease\s*=\s*'([^']*)'/m)?.[1];
	const moduleVersion = prerelease ? `${version}-${prerelease}` : version;
	const commit = git('rev-parse --short HEAD');
	// A build from a release tag shows only the version; any other build adds the commit.
	const tag = process.env.GITHUB_REF_TYPE === 'tag' ? process.env.GITHUB_REF_NAME : git('tag --points-at HEAD');
	const released = /^v\d/m.test(tag ?? '');
	fs.mkdirSync(generatedRoot, { recursive: true });
	fs.writeFileSync(
		path.join(generatedRoot, 'build-info.json'),
		JSON.stringify({ version: moduleVersion, display: released || !commit ? `v${moduleVersion}` : `v${moduleVersion}+${commit}`, commit }, null, '\t') + '\n',
	);
}

function git(args) {
	try {
		return execSync(`git ${args}`, { cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
	} catch {
		return '';
	}
}

function slugFor(relative) {
	const parts = toPosix(relative).replace(/\.md$/, '').split('/');
	if (parts.at(-1).toLowerCase() === 'readme') {
		parts.pop();
	}
	return parts.map(slugify).join('/');
}

function slugify(name) {
	return name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

function toPosix(p) {
	return p.split(path.sep).join('/');
}

function walk(dir) {
	return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
		const full = path.join(dir, entry.name);
		return entry.isDirectory() ? walk(full) : [full];
	});
}
