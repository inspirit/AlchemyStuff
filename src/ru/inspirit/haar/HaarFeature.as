package ru.inspirit.haar 
{

	/**
	 * @author Eugene Zatepyakin
	 */
	internal final class HaarFeature
	{
		//public var tilted:Boolean;
		public var threshold:Number;
		public var leftVal:Number;
		public var rightVal:Number;
		public var leftNode:HaarFeature;
		public var rightNode:HaarFeature;
		public var nextFeature:HaarFeature;
		public var rn:int;
		public var hfr:HaarFeatureRect;
	}
}
