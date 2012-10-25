package ru.inspirit.haar 
{

	/**
	 * @author Eugene Zatepyakin
	 */
	internal final class HaarFeatureRect
	{
		public var x:int;
		public var y:int;
		public var w:int;
		public var h:int;
		public var n1:int;
		public var n2:int;
		public var n3:int;
		public var n4:int;
		public var weight:Number;
		public var nextRect:HaarFeatureRect;
		public var nextChainRect:HaarFeatureRect;
	}
}
