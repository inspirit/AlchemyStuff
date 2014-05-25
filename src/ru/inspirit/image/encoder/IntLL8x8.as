package ru.inspirit.image.encoder
{
	internal final class IntLL8x8 
	{
		public var data:int;
		public var next:IntLL8x8;
		public var down:IntLL8x8;
		
		public function IntLL8x8(dt:int, nx:IntLL8x8, dn:IntLL8x8) 
		{
			data = dt;
			next = nx;
			down = dn;
		}
		
		public static function create(arr:Array):IntLL8x8 
		{
			//if(arr.length != 64) throw new Error("Need an 8*8 array!");

			var i:int = arr.length;
			var item:IntLL8x8 = null;
			var c7:IntLL8x8 = item = new IntLL8x8(arr[--i], item, null);
			var c6:IntLL8x8 = item = new IntLL8x8(arr[--i], item, null);
			var c5:IntLL8x8 = item = new IntLL8x8(arr[--i], item, null);
			var c4:IntLL8x8 = item = new IntLL8x8(arr[--i], item, null);
			var c3:IntLL8x8 = item = new IntLL8x8(arr[--i], item, null);
			var c2:IntLL8x8 = item = new IntLL8x8(arr[--i], item, null);
			var c1:IntLL8x8 = item = new IntLL8x8(arr[--i], item, null);
			var c0:IntLL8x8 = item = new IntLL8x8(arr[--i], item, null);
			while(i != 0) {
				c7 = item = new IntLL8x8(arr[--i], item, c7);
				c6 = item = new IntLL8x8(arr[--i], item, c6);
				c5 = item = new IntLL8x8(arr[--i], item, c5);
				c4 = item = new IntLL8x8(arr[--i], item, c4);
				c3 = item = new IntLL8x8(arr[--i], item, c3);
				c2 = item = new IntLL8x8(arr[--i], item, c2);
				c1 = item = new IntLL8x8(arr[--i], item, c1);
				c0 = item = new IntLL8x8(arr[--i], item, c0);
			}
			return item;
		}
	}
}
