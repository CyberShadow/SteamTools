/// Install all Linux games under 100 MB

import std.algorithm;
import std.array;
import std.conv;
import std.json;

import ae.utils.array;

import cache;
import steamcmd;

void main()
{
	SteamCMD steam;
	steam.start(`/home/vladimir/opt/steamcmd/steamcmd.sh`);
	steam.login("the_cybershadow");
	auto licenses = steam.getLicenses();
	foreach (id; licenses.map!(license => steam.getPackageInfoCached(license.packageID)[license.packageID.text]["appids"].nodes.map!(node => node.value.to!int)).join.sort().uniq)
	{
		auto info = steam.getAppInfoCached(id);
		bool installable = false;
		auto root = info[id.text];
		bool haveLinux, big;
		if ("depots" !in root)
			continue;
		foreach (depot; root["depots"].nodes)
		{
			if (depot.key == "branches" || !depot.nodes)
				continue;
			try
				haveLinux |= depot["config"]["oslist"].value.split(",").contains("linux");
			catch (Exception e) {}
			try
				big |= depot["maxsize"].value.to!long > 100*1024*1024;
			catch (Exception e) {}
		}
		if (haveLinux && !big)
			steam.install(id);
	}
	steam.quit();
}
