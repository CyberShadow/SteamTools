import core.time;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.datetime.systime;
import std.file;
import std.regex;
import std.string;

import ae.sys.net;
import ae.sys.net.cachedcurl;
import ae.utils.json;
import ae.utils.regex;
import ae.utils.time.common;
import ae.utils.time.format;

struct UserTag
{
	int tagid;
	string name;
	int count;
	bool browseable;
}

struct GameTag
{
	string name;
	int id;
}

struct StorePage
{
	string url;
	UserTag[] userTags;
	GameTag[] gameTags;
}

StorePage getStorePage(int appID)
{
	StorePage result;
	result.url = "http://store.steampowered.com/app/" ~ appID.text ~ "/";
	try
		result.url = resolveRedirect(result.url);
	catch (Exception e)
	{}

	if (result.url == "http://store.steampowered.com/")
		throw new Exception("No such page (redirect to /)");
	if (result.url.startsWith("http://store.steampowered.com/app/") && result.url.split("/")[4] != appID.text)
		throw new Exception("No such page (redirect to another AppID)");

	auto html = cast(string)getFile(result.url);
	scope(failure) std.file.write("bad.html", html);

	result.userTags = html
		.split("\r\n")
		.findSplit!startsWith(["\t\t\tInitAppTagModal( "])[2][0]
		.chomp(",")
		.jsonParse!(UserTag[]);

	result.gameTags = html
		.matchAll(re!`<div class="game_area_details_specs"><div class="icon"><a href="http://store.steampowered.com/search/\?category2=(\d+)&snr=[0-9_]*"><img class="category_icon" src="http://store.edgecast.steamstatic.com/public/images/v6/ico/ico_\w+.png"></a></div><a class="name" href="http://store.steampowered.com/search/\?category2=\d+&snr=[0-9_]*">(.*?)</a></div>`)
		.map!(m => GameTag(m[2], m[01].to!int))
		.array;

	return result;
}

CachedCurlNetwork ccnet;

static this()
{
	ccnet = cast(CachedCurlNetwork)net;
	ccnet.http.verbose = true;
	ccnet.cookieDir = "cookies";
	mkdirRecurse("cookies");
	SysTime birthday = Clock.currTime() - (25*365).days;
	std.file.write("cookies/store.steampowered.com",
		"birthtime=%d; lastagecheckage=%2d-%s-%d; mature_content=1".format(
			birthday.toUnixTime,
			birthday.day,
			MonthLongNames[birthday.month-1],
			birthday.year,
		));
}
