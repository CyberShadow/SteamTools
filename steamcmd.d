import std.algorithm;
import std.conv;
import std.datetime;
import std.exception;
import std.file : readText;
import std.process;
import std.range;
import std.stdio;
import std.string;

import ae.utils.regex;
import ae.utils.time;

import config;
import vdf;

struct SteamCMD
{
	ProcessPipes p;

	string[] output;

	void waitLine(string soughtLine)
	{
		output = null;
		while (true)
		{
			auto line = p.stdout.readln().chomp();
			line.skipOver("Steam>\x1B[0m");
			stderr.writeln("> ", line);
			if (line == soughtLine)
				return;
			else
				output ~= line;
		}
	}

	void waitPrompt()
	{
		waitLine("\x1B[1m");
	}

	void sendLine(string line)
	{
		stderr.writeln("< ", line);
		p.stdin.writeln(line);
		p.stdin.flush();
	}

	void start()
	{
		p = pipeProcess([getConfig().steamcmd], Redirect.stdin | Redirect.stdout);

		waitLine("Loading Steam API...OK");
		stderr.writeln("* Steam started OK.");
	}

	void quit()
	{
		sendLine("quit");
		p.pid.wait();
	}

	void login(string[] credentials...)
	{
		if (!credentials.length)
			credentials = getConfig().credentials.split;
		sendLine("login " ~ credentials.join(" "));
		waitLine("Waiting for user info...OK");
		stderr.writeln("* Log in OK.");
	}

	struct License
	{
		int packageID;
		string state;
		int flags;
		SysTime purchaseDate;
		string purchaseLocation, purchaseMethod;

		int[] someApps, someDepots; /// Incomplete!!!
		int numApps, numDepots;
	}

	License[] getLicenses()
	{
		sendLine("licenses_print");
		// waitLine("Waiting for license info...OK");
		stderr.writefln("* Receiving license lines.");
		waitPrompt();
		waitPrompt();
		enforce(output.length % 4 == 0, "Wrong modulus of licenses_print output length");

		License[] result;
		foreach (chunk; output.chunks(4))
		{
			scope(failure) stderr.writeln("Error with: ", chunk);
			License license;
			string purchaseDateStr, appsStr, depotsStr, flagsStr;
			enforce(chunk[0].matchInto(`^License packageID (\d+):$`, license.packageID), chunk[0]);
			enforce(chunk[1].matchInto(`^ - State   : (\w+) \(flags 0x([0-9a-f]+)\) - Purchased : (\w\w\w \w\w\w +\d+ \d\d:\d\d:\d\d \d\d\d\d) in "(.*)", (.*)$`,
					license.state, flagsStr, purchaseDateStr, license.purchaseLocation, license.purchaseMethod), chunk[1]);
			enforce(chunk[2].matchInto(`^ - Apps\t: (.*) \((\d+) in total\)$`, appsStr, license.numApps), chunk[2]);
			enforce(chunk[3].matchInto(`^ - Depots   : (.*) \((\d+) in total\)$`, depotsStr, license.numDepots), chunk[3]);

			license.flags = flagsStr.to!int(16);
			license.purchaseDate = purchaseDateStr.parseTime!`D M d H:i:s Y`();
			license.someApps   = appsStr  .split(", ").filter!(s => s.length && s != "...").map!(to!int).array();
			license.someDepots = depotsStr.split(", ").filter!(s => s.length && s != "...").map!(to!int).array();
			result ~= license;
		}

		stderr.writefln("* Got %s licenses.", result.length);
		return result;
	}

	VDF getPackageInfo(int id)
	{
		sendLine("package_info_print " ~ text(id));
		stderr.writefln("* Receiving package info.");
		waitPrompt();
		stderr.writefln("* Got package info.");
		return parseVDF(output[1..$].join("\n") ~ "\n");
	}

	VDF getAppInfo(int id)
	{
		sendLine("app_info_print " ~ text(id));
		stderr.writefln("* Receiving app info.");
		waitPrompt();
		stderr.writefln("* Got app info.");
		return parseVDF(output[1..$].join("\n") ~ "\n");
	}

	void install(int id, bool validate = false)
	{
		sendLine("app_update %d%s".format(id, validate ? " validate" : ""));
		stderr.writefln("* Installing app.");
		waitPrompt();
		stderr.writefln("* App installed.");
	}
}
