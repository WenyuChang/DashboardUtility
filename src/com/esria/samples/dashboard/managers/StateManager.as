package com.esria.samples.dashboard.managers
{
	import com.esria.samples.dashboard.events.LayoutChangeEvent;
	import com.esria.samples.dashboard.view.Pod;
	
	import flash.net.SharedObject;
		
	public class StateManager
	{
		public static var sharedObject:SharedObject = SharedObject.getLocal("com.esria.sample.dashboard");
		
		private static const VIEW_INDEX:String = "viewIndex";
		private static const ITEMS:String = "items";
		private static const MINIMIZED_ITEMS:String = "minimizedItems";
		private static const MAXIMIZED_ITEM:String = "maximizedItem";
		private static const POD_VIEW_INDEXES:String = "podViewIndexes";
		
		public static function setPodLayout(e:LayoutChangeEvent):void
		{
			var manager:PodLayoutManager = PodLayoutManager(e.currentTarget);
			var o:Object = getViewIdObject(manager.id);
			o[MAXIMIZED_ITEM] = manager.maximizedPod != null ? manager.maximizedPod.id : null;
			o[MINIMIZED_ITEMS] = podArrayToStringArray(manager.minimizedItems);;
			o[ITEMS] = podArrayToStringArray(manager.items);
			sharedObject.flush();
		}
		
		private static function podArrayToStringArray(podArray:Array):Array
		{
			var len:Number = podArray.length;
			var a:Array = new Array();
			for (var i:Number = 0; i < len; i++)
			{
				a.push(Pod(podArray[i]).id);
			}
			return a;
		}
		
		public static function getPodIndex(viewId:String, itemId:String):Number
		{
			var o:Object = getViewIdObject(viewId);
			var a:Array = o[ITEMS];
			if (a != null)
			{
				var len:Number = a.length;
				for (var i:Number = 0; i < len; i++)
				{
					if (a[i] == itemId)
						return i;
				}
			}
			return -1;
		}
		
		public static function getMinimizedPodIndex(viewId:String, itemId:String):Number
		{
			var o:Object = getViewIdObject(viewId);
			var a:Array = o[MINIMIZED_ITEMS];
			if (a != null)
			{
				var len:Number = a.length;
				for (var i:Number = 0; i < len; i++)
				{
					if (a[i] == itemId)
						return i;
				}
			}
			return -1;
		}
		
		public static function isPodMaximized(viewId:String, itemId:String):Boolean
		{
			var o:Object = getViewIdObject(viewId);
			return o[MAXIMIZED_ITEM] == itemId;
		}
		
		private static function getViewIdObject(viewId:String):Object
		{
			if (sharedObject.data[viewId] == null)
				sharedObject.data[viewId] = new Object();
			return sharedObject.data[viewId];
		}
	}
}