package com.esria.samples.dashboard.events
{
	import flash.events.Event;
	
	public class PodStateChangeEvent extends Event
	{
		public static var MINIMIZE:String = "minimize";
		public static var RESTORE:String = "restore";
		public static var MAXIMIZE:String = "maximize";
		
		public function PodStateChangeEvent(type:String)
		{
			super(type, true, true);
		}
	}
}