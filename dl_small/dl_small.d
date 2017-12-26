/// Install all Linux games under 100 MB

import std.algorithm;
import std.array;
import std.conv;
import std.json;

import ae.utils.array;

import steam;

void main()
{
	SteamCMD steam;
	steam.start(`/home/vladimir/opt/steamcmd/steamcmd.sh`);
	steam.login("the_cybershadow");
	auto licenses = steam.getLicenses();
	foreach (id; licenses.map!(license => license.apps).join.sort().uniq)
	{
		auto info = steam.getAppInfo(id);
		bool installable = false;
		auto root = info.info[id.text];
		if (root.type != JSON_TYPE.OBJECT)
			continue;
		if ("depots" !in root.object)
			continue;
		bool haveLinux, big;
		foreach (depotId, depotData; root["depots"].object)
		{
			if (depotId == "branches" || depotData.type != JSON_TYPE.OBJECT)
				continue;
			if ("config" in depotData &&
				"oslist" in depotData["config"] &&
				depotData["config"]["oslist"].str.split(",").contains("linux"))
				haveLinux = true;
			if ("maxsize" in depotData &&
				depotData["maxsize"].str.to!long > 100*1024*1024)
				big = true;
		}
		if (haveLinux && !big)
			steam.install(id);
	}
	steam.quit();
}
