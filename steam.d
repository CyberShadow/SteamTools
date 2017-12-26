import std.algorithm;
import std.conv;
import std.datetime;
import std.json;
import std.process;
import std.range;
import std.stdio;
import std.string;

import ae.utils.regex;
import ae.utils.time;

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

	void start(string steamCmdPath)
	{
		p = pipeProcess([steamCmdPath], Redirect.stdin | Redirect.stdout);

		waitLine("Loading Steam API...OK.");
		stderr.writeln("* Steam started OK.");
	}

	void quit()
	{
		sendLine("quit");
		p.pid.wait();
	}

	void login(string[] credentials...)
	{
		sendLine("login " ~ credentials.join(" "));
		waitLine("Logged in OK");
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
		int[] apps, depots;
	}

	License[] getLicenses()
	{
		sendLine("licenses_print");
		// waitLine("Waiting for license info...OK");
		stderr.writefln("* Receiving license lines.");
		waitPrompt();
		waitPrompt();
		assert(output.length % 4 == 0, "Wrong modulus of licenses_print output length");

		License[] result;
		foreach (chunk; output.chunks(4))
		{
			scope(failure) stderr.writeln("Error with: ", chunk);
			License license;
			string purchaseDateStr, appsStr, depotsStr;
			assert(chunk[0].matchInto(`^License packageID (\d+):$`, license.packageID), chunk[0]);
			assert(chunk[1].matchInto(`^ - State   : (\w+)\( flags (\d+) \) - Purchased : (\w\w\w \w\w\w +\d+ \d\d:\d\d:\d\d \d\d\d\d) in "(.*)", (.*)$`,
					license.state, license.flags, purchaseDateStr, license.purchaseLocation, license.purchaseMethod), chunk[1]);
			assert(chunk[2].matchInto(`^ - Apps    : (.*) \(\d+ in total\)$`, appsStr), chunk[2]);
			assert(chunk[3].matchInto(`^ - Depots   : (.*) \(\d+ in total\)$`, depotsStr), chunk[3]);

			license.purchaseDate = purchaseDateStr.parseTime!`D M d H:i:s Y`();
			license.apps   = appsStr  .split(", ").filter!(s => s.length && s != "...").map!(to!int).array();
			license.depots = depotsStr.split(", ").filter!(s => s.length && s != "...").map!(to!int).array();
			result ~= license;
		}

		stderr.writefln("* Got %s licenses.", result.length);
		return result;
	}

	struct AppInfo
	{
		JSONValue info;
	}

	AppInfo getAppInfo(int id)
	{
		sendLine("app_info_print " ~ text(id));
		stderr.writefln("* Receiving app info.");
		waitPrompt();
		AppInfo result;

		struct Reader
		{
			string data;

			void skipWhiteSpace()
			{
				while (data.skipOver("\t")) {}
			}

			string readString()
			{
				skipWhiteSpace();
				assert(data.skipOver("\""));
				auto p = data.findSplit("\"\t\t");
				data = p[2];
				skipWhiteSpace();
				return p[0];
			}

			JSONValue readObject()
			{
				JSONValue result;
				while (true)
				{
					skipWhiteSpace();
					if (data.skipOver("}"))
						return result;
					else
						readKeyValue(result);
				}
			}

			void readKeyValue(ref JSONValue obj)
			{
				auto name = readString();
				if (data.skipOver("{"))
					obj[name] = readObject();
				else
					obj[name] = readString();
				skipWhiteSpace();
			}
		}

		auto reader = Reader(output[1..$].join("\t\t"));
		scope(failure) stderr.writeln("Error here: " ~ reader.data[0..min($, 100)]);
		while (reader.data.length)
			reader.readKeyValue(result.info);

		stderr.writefln("* Got app info.");
		return result;
	}

	void install(int id, bool validate = false)
	{
		sendLine("app_update %d%s".format(id, validate ? " validate" : ""));
		stderr.writefln("* Installing app.");
		waitPrompt();
		stderr.writefln("* App installed.");
	}
}