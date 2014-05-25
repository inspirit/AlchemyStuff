package ru.inspirit.image.encoder
{
	internal final class IntLL 
	{
		public var data:int;
		public var next:IntLL;
		
		public function IntLL(dt:int, nx:IntLL) 
		{
			data = dt;
			next = nx;
		}
		
		public static function create(arr:Array):IntLL 
		{
			var i:int = arr.length;
			var itm:IntLL = new IntLL(arr[--i], null);
			while (--i > -1) {
				itm = new IntLL(arr[i], itm);
			}
			return itm;
		}
	}
}
