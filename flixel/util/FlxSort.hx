package flixel.util;

import flixel.FlxObject;

/**
 * Helper class for sort() in FlxTypedGroup, but could theoretically be used on regular arrays as well.
 */
class FlxSort
{
	public static inline var ASCENDING:Int = -1;
	public static inline var DESCENDING:Int = 1;

	  /**
   * You can use this function in FlxTypedGroup.sort() to sort FlxObjects by their z-index values.
   * The value defaults to 0, but by assigning it you can easily rearrange objects as desired.
   *
   * @param order Either `FlxSort.ASCENDING` or `FlxSort.DESCENDING`
   * @param a The first FlxObject to compare.
   * @param b The second FlxObject to compare.
   * @return 1 if `a` has a higher z-index, -1 if `b` has a higher z-index.
   */
  public static inline function byZIndex(order:Int, a:FlxBasic, b:FlxBasic):Int
  {
    if (a == null && b == null) return 0;
    if (a == null) return order;
    if (b == null) return -order;
    return byValues(order, a.zIndex, b.zIndex);
  }

	/**
	 * You can use this function in FlxTypedGroup.sort() to sort FlxObjects by their y values.
	 */
	public static inline function byY(Order:Int, Obj1:FlxObject, Obj2:FlxObject):Int
	{
		return byValues(Order, Obj1.y, Obj2.y);
	}

	/**
	 * You can use this function as a backend to write a custom sorting function (see byY() for an example).
	 */
	public static inline function byValues(Order:Int, Value1:Float, Value2:Float):Int
	{
		var result:Int = 0;

		if (Value1 < Value2)
		{
			result = Order;
		}
		else if (Value1 > Value2)
		{
			result = -Order;
		}

		return result;
	}
}
