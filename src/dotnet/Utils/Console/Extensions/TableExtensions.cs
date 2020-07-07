namespace PoShLog.Core.Utils.Console.Extensions
{
	public static class TableExtensions
	{
		/// <summary>
		/// Adds one row with two cells into <see cref="Table"/> only if <paramref name="propertyValue"/> is not null or empty string.
		/// </summary>
		/// <param name="table"></param>
		/// <param name="propertyName"></param>
		/// <param name="propertyValue"></param>
		public static void AddPropertyRow(this Table table, string propertyName, object propertyValue)
		{
			if (propertyValue == null || (propertyValue is string propertyValueString && string.IsNullOrEmpty(propertyValueString)))
			{
				return;
			}

			table.AddRow(propertyName, propertyValue);
		}
	}
}
