using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace PoShLog.Core.Utils
{
	public class Cell
	{
		public const string NULL_PLACEHOLDER = "$null";

		public int Index { get; }
		public string Value { get; }
		public static int MaxWidth { get; private set; }

		public Row Row { get; }
		public Column Column { get; set; }

		public int Width => Value.Length;

		public Cell(object value, int index, Row row)
		{
			Index = index;
			Value = value?.ToString() ?? NULL_PLACEHOLDER;
			MaxWidth = Width > MaxWidth ? Width : MaxWidth;
			Row = row;
		}

		public override string ToString()
		{
			return Value.PadRight(Column.MaxWidth, ' ');
		}
	}

	public class Column
	{
		public int Index { get; }
		public List<Cell> Cells { get; } = new List<Cell>();

		public int MaxWidth => Cells.Max(c => c.Width);

		public Column(int index)
		{
			Index = index;
		}

		public Column(Cell cell)
		{
			AddCell(cell);
			Index = cell.Index;
		}

		public void AddCell(Cell cell)
		{
			Cells.Add(cell);
			cell.Column = this;
		}
	}

	public class Row
	{
		public bool IsHeader { get; }
		public int Index { get; }
		public List<Cell> Cells { get; }
		public bool DisableTopGrid { get; set; }

		public Row(int index, bool isHeader = false, params object[] values)
			: this(index, isHeader, values?.Select(v => v?.ToString() ?? Cell.NULL_PLACEHOLDER).ToArray())
		{
		}

		public Row(int index, bool isHeader = false, params string[] values)
		{
			if (values == null)
			{
				throw new ArgumentException("You must provide cells when creating row!", nameof(values));
			}

			int cellIndex = 0;
			Cells = new List<Cell>(values.Select(v => new Cell(v, cellIndex++, this)));
			Index = index;
			IsHeader = isHeader;
		}
	}

	public class Table
	{
		public const string TOP_LEFT_JOINT = "┌";
		public const string TOP_RIGHT_JOINT = "┐";
		public const string BOTTOM_LEFT_JOINT = "└";
		public const string BOTTOM_RIGHT_JOINT = "┘";
		public const string TOP_JOINT = "┬";
		public const string BOTTOM_JOINT = "┴";
		public const string LEFT_JOINT = "├";
		public const string MIDDLE_JOINT = "┼";
		public const string RIGHT_JOINT = "┤";
		public const char HORIZONTAL_LINE = '─';
		public const string VERTICAL_LINE = "│";

		private List<Row> Rows { get; } = new List<Row>();
		private List<Column> Columns { get; set; }

		public bool HeaderSet { get; set; }
		public int Padding { get; set; } = 1;

		private int _rowIndex;

		public void SetHeader(params string[] headers)
		{
			HeaderSet = true;
			Rows.Add(new Row(_rowIndex++, true, headers));
		}

		public void AddRow(params object[] values)
		{
			// In case there is multiline cell value we need to divide it into multiple rows
			if (values.Any(v => v?.ToString().Contains(Environment.NewLine) ?? false))
			{
				var maxLines = values.Max(v => v.ToString().Split('\n').Length);
				for (int i = 0; i < maxLines; i++)
				{
					var row = new List<object>();
					foreach (var value in values)
					{
						var valueLines = value.ToString().Split('\n');
						if (i < valueLines.Length)
						{
							row.Add(valueLines[i].Replace("\r", ""));
						}
						else
						{
							row.Add(string.Empty);
						}
					}

					Rows.Add(new Row(_rowIndex++, false, row.ToArray()) { DisableTopGrid = i > 0 });
				}
			}
			else
			{
				AddRow(false, values);
			}
		}

		private void AddRow(bool isHeader = false, params object[] values)
		{
			Rows.Add(new Row(_rowIndex++, isHeader, values));
		}

		private void CalculateColumns()
		{
			Columns = new List<Column>();
			foreach (var row in Rows)
			{
				foreach (var cell in row.Cells)
				{
					if (row.Index == 0)
					{
						Columns.Add(new Column(cell));
					}
					else
					{
						Columns.SingleOrDefault(c => c.Index == cell.Index)?.AddCell(cell);
					}
				}
			}
		}

		public string Render()
		{
			var sb = new StringBuilder();
			CalculateColumns();

			string ps = string.Concat(Enumerable.Repeat(' ', Padding));

			foreach (var row in Rows)
			{
				// Don't render grid if row is multiline
				if (!row.DisableTopGrid)
				{
					RenderGrid(sb, row.Index);
				}

				foreach (var cell in row.Cells)
				{
					sb.Append($"{VERTICAL_LINE}{ps}{cell}{ps}");
				}
				sb.AppendLine(VERTICAL_LINE);

				RenderGrid(sb, row.Index, false);
			}

			return sb.ToString();
		}

		private void RenderGrid(StringBuilder sb, int rowIndex, bool preRender = true)
		{
			if (rowIndex == 0 && preRender) // First line
			{
				RenderGridLine(sb, TOP_LEFT_JOINT, TOP_JOINT, TOP_RIGHT_JOINT);
			}
			else if (rowIndex == Rows.Count - 1 && !preRender)  // Last line
			{
				RenderGridLine(sb, BOTTOM_LEFT_JOINT, BOTTOM_JOINT, BOTTOM_RIGHT_JOINT);
			}
			else if (preRender) // Middle line
			{
				RenderGridLine(sb, LEFT_JOINT, MIDDLE_JOINT, RIGHT_JOINT);
			}
		}

		private void RenderGridLine(StringBuilder sb, string leftJoint, string middleJoint, string rightJoint)
		{
			for (int i = 0; i < Columns.Count; i++)
			{
				var columnWidth = Columns[i].MaxWidth + Padding * 2;
				if (i == 0)
				{
					sb.Append(leftJoint + string.Empty.PadLeft(columnWidth, HORIZONTAL_LINE) + middleJoint);
				}
				else if (i == Columns.Count - 1)
				{
					sb.Append(string.Empty.PadLeft(columnWidth, HORIZONTAL_LINE) + rightJoint);
				}
				else
				{
					sb.Append(string.Empty.PadLeft(columnWidth, HORIZONTAL_LINE) + middleJoint);
				}
			}

			sb.AppendLine();
		}

		public override string ToString()
		{
			return Render();
		}
	}
}
