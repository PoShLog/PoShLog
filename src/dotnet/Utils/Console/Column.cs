using System.Collections.Generic;
using System.Linq;

namespace PoShLog.Core.Utils.Console
{
	internal class Column
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
}