package ru.inspirit.haar
{
	import apparat.inline.Inlined;
	import apparat.math.FastMath;

	import flash.geom.Rectangle;

	/**
	 * @author Eugene Zatepyakin
	 */
	internal final class HaarInline extends Inlined
	{
		public static function similarRects(r1:Rectangle, r2:Rectangle):Boolean
		{
			var eps:Number = 0.2;
			var delta:Number = eps * (FastMath.min(r1.width, r2.width) + FastMath.min(r1.height, r2.height)) * 0.5;
			var chk:int = int(FastMath.abs(r1.x - r2.x) <= delta) &
							int(FastMath.abs(r1.y - r2.y) <= delta) &
							int(FastMath.abs(r1.x + r1.width - r2.x - r2.width) <= delta) &
							int(FastMath.abs(r1.y + r1.height - r2.y - r2.height) <= delta);
			return Boolean(chk);
	        /*
			return 		FastMath.abs(r1.x - r2.x) <= delta &&
	        			FastMath.abs(r1.y - r2.y) <= delta &&
	        			FastMath.abs(r1.x + r1.width - r2.x - r2.width) <= delta &&
	        			FastMath.abs(r1.y + r1.height - r2.y - r2.height) <= delta;
						*/
		}
	}
}
