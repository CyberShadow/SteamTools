/// Split text into parts that would fit into individual review
/// comments, and prepend pagers.

import std.algorithm.iteration;
import std.algorithm.mutation;
import std.array;
import std.stdio;
import std.string;
import std.file;

enum limit = 1000;

void main(string[] args)
{
	auto files = args[1..$];
	foreach (fn; files)
	{
		auto s = fn.readText();
		auto parts = s.split("||").map!strip().array;
		bool ok = true;
		foreach (n, ref p; parts)
		{
			p = "[%d/%d] %s".format(n+1, parts.length, p);
			writefln("Part %d - %d/%d bytes", n+1, parts.length, p.length, limit);
			if (p.length > limit)
				ok = false;
		}
		if (ok)
			foreach (n, p; parts)
			{
				writeln();
				writefln("----- Part %d -----", n+1);
				writeln(p);
			}
		else
			writeln("Not OK");
	}
}
