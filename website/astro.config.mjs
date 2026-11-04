// The PoShLog documentation website (ADR 0022). Pages come from ../docs through scripts/sync-docs.mjs.
import starlight from '@astrojs/starlight';
import { defineConfig } from 'astro/config';

// SITE_URL and SITE_BASE choose where the site is served; the default is the org site at the root.
const site = process.env.SITE_URL ?? 'https://poshlog.github.io';
const base = process.env.SITE_BASE ?? '/';

const cmdlet = (name) => ({ label: name, link: `/cmdlets/${name.toLowerCase()}/` });

export default defineConfig({
	site,
	base,
	trailingSlash: 'always',
	integrations: [
		starlight({
			title: 'PoShLog',
			description: 'Structured logging for PowerShell, built on Serilog.',
			logo: { src: './src/generated/icon.png', alt: 'PoShLog' },
			favicon: '/favicon.png',
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/PoShLog/PoShLog' }],
			customCss: ['./src/styles/custom.css'],
			components: { Footer: './src/components/Footer.astro' },
			lastUpdated: false,
			credits: false,
			sidebar: [
				{
					label: 'Getting started',
					items: [
						{ label: 'Getting started', link: '/getting-started/' },
						{ label: 'v2 or v3?', link: '/v2-or-v3/' },
						{ label: 'Compatibility and installation', link: '/compatibility/' },
					],
				},
				{
					label: 'Concepts',
					items: [
						{ label: 'Usage and message templates', link: '/usage/' },
						{ label: 'Log event levels', link: '/log-event-levels/' },
						{ label: 'Enrichers', link: '/guides/enrichers/' },
						{ label: 'Capturing console output', link: '/guides/capturing-output/' },
						{ label: 'Extension modules', link: '/guides/extension-modules/' },
					],
				},
				{
					label: 'Cmdlets',
					collapsed: true,
					items: [
						{ label: 'All cmdlets', link: '/cmdlets/' },
						{
							label: 'Logger',
							items: ['New-Logger', 'Start-Logger', 'Close-Logger', 'Get-Logger', 'Set-Logger'].map(cmdlet),
						},
						{
							label: 'Writing events',
							items: [
								{ label: 'Write cmdlets', link: '/cmdlets/write-cmdlets/' },
								...['Write-VerboseLog', 'Write-DebugLog', 'Write-InfoLog', 'Write-WarningLog', 'Write-ErrorLog', 'Write-FatalLog'].map(cmdlet),
							],
						},
						{
							label: 'Core sinks',
							items: ['Add-SinkConsole', 'Add-SinkFile', 'Add-SinkPowerShell', 'Add-SinkLogger'].map(cmdlet),
						},
						{ label: 'Levels', items: ['Set-MinimumLevel', 'New-LevelSwitch', 'Set-LevelSwitch'].map(cmdlet) },
						{
							label: 'Enrichment',
							items: ['Add-EnrichWithProperty', 'Add-EnrichWithErrorRecord', 'Add-EnrichFromLogContext', 'Push-LogContextProperty'].map(cmdlet),
						},
						{ label: 'Formatters', items: ['Get-JsonFormatter', 'Get-CompactFormatter', 'Set-DefaultMessageFormatter'].map(cmdlet) },
						{ label: 'Extensions', items: ['Get-PoShLogExtension', 'Install-PoShLogExtension'].map(cmdlet) },
						{ label: 'Diagnostics and helpers', items: ['Enable-SelfLog', 'Disable-SelfLog', 'Get-CurrentLogFiles', 'Convert-LogFunctions'].map(cmdlet) },
					],
				},
				{
					label: 'Sinks',
					collapsed: true,
					items: [
						{ label: 'Overview', link: '/sinks/' },
						{ label: 'OpenTelemetry (OTLP)', link: '/sinks/add-sinkopentelemetry/' },
						{ label: 'Seq', link: '/extensions/poshlog-sinks-seq/' },
						{ label: 'Elasticsearch', link: '/sinks/add-sinkelasticsearch/' },
						{ label: 'SQL Server', link: '/sinks/add-sinkmssqlserver/' },
						{ label: 'Splunk HEC', link: '/sinks/add-sinksplunk/' },
						{ label: 'Syslog', link: '/sinks/add-sinksyslog/' },
						{ label: 'Windows Event Log', link: '/sinks/add-sinkeventlog/' },
						{ label: 'HTTP', link: '/extensions/poshlog-sinks-http/' },
						{ label: 'Creating a sink', link: '/guides/creating-sink/' },
					],
				},
				{ label: 'Enrichers', collapsed: true, items: [{ autogenerate: { directory: 'enrichers' } }] },
				{ label: 'Recipes', items: [{ autogenerate: { directory: 'recipes' } }] },
				{
					label: 'Migrating',
					items: [
						{ label: 'From PoShLog 2', link: '/guides/migration-v3/' },
						{ label: 'From Write-Host and transcripts', link: '/guides/migration-write-host/' },
						{ label: 'From PSFramework', link: '/guides/migration-psframework/' },
					],
				},
				{
					label: 'Reference',
					collapsed: true,
					items: [
						{ label: 'FAQ and troubleshooting', link: '/guides/faq/' },
						{ label: 'Assembly conflicts', link: '/guides/assembly-conflicts/' },
						{ label: 'Changelog', link: '/changelog/' },
						{ label: 'Extension module READMEs', collapsed: true, items: [{ autogenerate: { directory: 'extensions' } }] },
						{ label: 'For developers', link: '/guides/for-developers/' },
						{ label: 'Architectural decisions', collapsed: true, items: [{ autogenerate: { directory: 'decisions' } }] },
					],
				},
			],
		}),
	],
});
