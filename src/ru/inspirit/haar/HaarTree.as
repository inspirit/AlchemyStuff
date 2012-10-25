package ru.inspirit.haar 
{

	/**
	 * @author Eugene Zatepyakin
	 */
	internal final class HaarTree
	{
		public var nextTree:HaarTree;
		public var features:HaarFeature;
		public var featuresMap:Vector.<HaarFeature>;
	}
}
