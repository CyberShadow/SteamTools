import std.algorithm.iteration;
import std.algorithm.searching;
import std.algorithm.sorting;
import std.array;
import std.ascii;
import std.conv;
import std.digest.sha;
import std.file;
import std.format;
import std.parallelism;
import std.path;
import std.range;
import std.stdio;

import ae.sys.persistence.keyvalue;
import ae.utils.array;
import ae.utils.meta;
import ae.utils.time.format;

import cache;
import config;
import steamcmd;
import vdf;
import web;

enum CatPrefix : string
{
	all           = "\uFE01",
	error         = "\uFE01" ~ "E: ",
	gameTag       = "\uFE01" ~ "F: ",
	userTag       = "\uFE01" ~ "T: ",
	review        = "\uFE02" ~ "R: ",
	developer     = "\uFE02" ~ "D: ",
	datePurchased = "\uFE03",
}

void main()
{
	string[string] reviewPrefix = [
		"Overwhelmingly Negative" : "\uFE01",
		"Very Negative"           : "\uFE02",
		"Negative"                : "\uFE03",
		"Mostly Negative"         : "\uFE04",
		"Mixed"                   : "\uFE05",
		"Mostly Positive"         : "\uFE06",
		"Positive"                : "\uFE07",
		"Very Positive"           : "\uFE08",
		"Overwhelmingly Positive" : "\uFE09",
	];

	SteamCMD steam;
	steam.start();
	steam.login();

	auto licenses = steam
		.getLicenses()
		.filter!(license => license.packageID != 0)
		.array;

	int[] appIDs;
	string[][int] categories;
	foreach (license; licenses)
	{
		auto licenseApps = steam.getPackageInfoCached(license.packageID)
			[license.packageID.text]
			["appids"]
			.nodes
			.map!(node => node.value.to!int)
			.array;
		appIDs ~= licenseApps;
		foreach (app; licenseApps)
			categories[app] ~= CatPrefix.datePurchased ~ "Added " ~ license.purchaseDate.formatTime!"Y-m-d";
	}
	appIDs = appIDs
		.sort
		.uniq
		.array;

	auto userDataDir = format!"%s/userdata/%s/7"(
		getConfig().steamPath.expandTilde,
		getConfig().accountId,
	);

	auto sharedConfigPath = userDataDir.buildPath("remote", "sharedconfig.vdf");
	auto sharedConfig = sharedConfigPath
		.readText()
		.parseVDF();

	auto appsConfig = &sharedConfig
		["UserRoamingConfigStore"]
		["Software"]
		["Valve"]
		["Steam"]
		["apps"];

	// File csv = File("review.csv", "wb");

	foreach (appID; appIDs)
	{
		scope(failure) writeln("Error with app ", appID);
		StorePage storePage;
		try
		{
			storePage = getStorePage(appID);
			// csv.writefln("%d,%d,%d,%s", storePage.reviewPercentage, storePage.reviewCount, appID, storePage.reviewSummary);
		}
		catch (Exception e)
		{
			string name;
			auto vdf = steam.getAppInfoCached(appID);
			try
				name = vdf[appID.text]["common"]["name"].value;
			catch (Exception e)
				name = "(unknown)";
			writeln(appID, " - ", name, " : ", e.msg);
			if (e.msg == "No such page (redirect to /)")
				categories[appID] ~= CatPrefix.error ~ "Gone";
			else
			if (e.msg == "No such page (redirect to another AppID)")
				categories[appID] ~= CatPrefix.error ~ "Redirect";
			else
			if (e.msg == "This item is currently unavailable in your region")
				categories[appID] ~= CatPrefix.error ~ "Region";
			else
				//categories[appID] ~= CatPrefix.error ~ "Error";
				throw e;
		}

		auto tags = chain(
				storePage.userTags
				.filter!(tag => tag.count >= storePage.userTags[0].count / 10)
				.map!(tag => CatPrefix.userTag ~ tag.name),

				storePage.gameTags
				.map!(tag => CatPrefix.gameTag ~ tag.name),

				storePage.reviewSummary.only.filter!identity.map!(r => CatPrefix.review ~ reviewPrefix.get(r, null) ~ r),

				// storePage.developers.map!(d => CatPrefix.developer ~ d),

				categories.get(appID, null),

				(CatPrefix.all ~ "All").only,
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
		.toFile(sharedConfigPath);

	if (false)  // Not actually necessary?
	{
		auto remoteCachePath = userDataDir.buildPath("remotecache.vdf");
		auto remoteCache = remoteCachePath
			.readText()
			.parseVDF();

		auto sharedConfigMeta = &remoteCache
			["7"]
			["sharedconfig.vdf"];
		(*sharedConfigMeta)["size"].value = getSize(sharedConfigPath).to!string;
		(*sharedConfigMeta)["sha"].value = readText(sharedConfigPath).sha1Of.toHexString!(LetterCase.lower).idup;
		(*sharedConfigMeta)["time"].value = timeLastModified(sharedConfigPath).toUnixTime.to!string;

		remoteCache
			.generateVDF
			.toFile(remoteCachePath);
	}

	if (false)
	{
		auto htmlCacheDir = format!"%s/config/htmlcache"(
			getConfig().steamPath.expandTilde,
		);
		rmdirRecurse(htmlCacheDir);  // Required to get Steam library to load the new sharedconfig.vdf
	}

	stderr.writeln("Done. Now, start Steam, then run:\n\nsteam://resetcollections\n\nand confirm the prompt in Steam.");
}
