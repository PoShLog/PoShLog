using System.Linq;

namespace PoShLog.Core.Utils.Console
{
	public class Padding
	{
		public int Right { get; set; }
		public int Left { get; set; }

		public Padding(int all)
		{
			Right = Left = all;
		}

		public Padding(int right, int left)
		{
			Right = right;
			Left = left;
		}

		public string RightString()
		{
			return PadString(Right);
		}

		public string LeftString()
		{
			return PadString(Left);
		}

		private string PadString(int padding)
		{
			return string.Concat(Enumerable.Repeat(' ', padding));
		}
	}
}