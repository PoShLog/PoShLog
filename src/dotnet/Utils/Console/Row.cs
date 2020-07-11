using System;
using System.Collections.Generic;
using System.Linq;

namespace PoShLog.Core.Utils.Console
{
	internal class Row
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
}