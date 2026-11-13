package flixel.group;

import flixel.FlxBasic;

/**
 * Small interface so that each flixel group class can have a common type.
 */
interface IFlxGroupable<T>
{
	public function add(member:T):T;
	public function remove(member:T, splice:Bool = false):T;
	public function clear():Void;
	public function getCameras():Array<FlxCamera>;
	public function refresh():Void;
}
