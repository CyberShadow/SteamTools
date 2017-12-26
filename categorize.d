import std.algorithm.iteration;
import std.algorithm.searching;
import std.algorithm.sorting;
import std.array;
import std.ascii;
import std.conv;
import std.file;
import std.parallelism;
import std.range;
import std.stdio;

import ae.sys.persistence.keyvalue;
import ae.utils.array;

import steam;
import vdf;
import web;

void main()
{
	auto db = KeyValueDatabase("cache.s3db");
	auto packages = KeyValueStore!(int, VDF)(&db, "packages");
	auto apps = KeyValueStore!(int, VDF)(&db, "apps");

	SteamCMD steam;
	steam.start(`/home/vladimir/opt/steamcmd/steamcmd.sh`);
	steam.login("the_cybershadow");

	auto appIDs = steam
		.getLicenses()
		.filter!(license => license.packageID != 0)
		.map!(license =>
			packages.getOrAdd(license.packageID,
				steam.getPackageInfo(license.packageID))
			[license.packageID.text]
			["appids"]
			.nodes
			.map!(node => node.value.to!int)
		)
		.join
		.array
		.sort
		.uniq
		.array;

	auto sharedConfig = "sharedconfig.vdf"
		.readText()
		.parseVDF();

	auto appsConfig = &sharedConfig
		["UserLocalConfigStore"]
		["Software"]
		["Valve"]
		["Steam"]
		["Apps"];

	foreach (appID; appIDs)
	{
		StorePage storePage;
		try
			storePage = getStorePage(appID);
		catch (Exception e)
		{
			string name;
			auto vdf = apps.getOrAdd(appID, steam.getAppInfo(appID));
			try
				name = vdf[appID.text]["common"]["name"].value;
			catch (Exception e)
				name = "(unknown)";
			writeln(appID, " - ", name, " : ", e.msg);
		}

		auto tags = chain(
				storePage.userTags
				.filter!(tag => tag.count >= storePage.userTags[0].count / 10)
				.map!(tag => "UT: " ~ tag.name),
				storePage.gameTags
				.map!(tag => "GT: " ~ tag.name),
			)
			.enumerate
			.map!(t => VDF(t.index.text, t.value))
			.array;
		if (!tags)
			tags = emptySlice!VDF;
		auto appNode = &appsConfig
			.getOrAdd(appID.text)
			.getOrAdd("tags");

		appNode.value = null; // clobber old empty string
		appNode.nodes = tags;
	}

	sharedConfig
		.generateVDF
		.toFile("sharedconfig.vdf");
}
