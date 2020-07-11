namespace PoShLog.Core.Utils.Console
{
	internal class Cell
	{
		public const string NULL_PLACEHOLDER = "";

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
}