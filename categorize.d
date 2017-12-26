import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.ascii;
import std.conv;
import std.file;
import std.stdio;

import vdf;

void main()
{
	auto sharedConfig = "sharedconfig.vdf"
		.readText()
		.parseVDF();

	auto gameIDs = sharedConfig["UserLocalConfigStore"]["Software"]["Valve"]["Steam"]["Apps"]
		.nodes
		.filter!(node => node.key.all!isDigit)
		.map!(node => node.key.to!int)
		.array;

	writeln(gameIDs);
}
