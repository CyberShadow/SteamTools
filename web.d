import core.time;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.algorithm.sorting;
import std.array;
import std.conv;
import std.datetime.systime;
import std.exception;
import std.file;
import std.range;
import std.regex;
import std.string;
import std.typecons;

import ae.sys.net;
import ae.sys.net.cachedcurl;
import ae.utils.array;
import ae.utils.json;
import ae.utils.meta;
import ae.utils.regex;
import ae.utils.time.common;
import ae.utils.time.format;

import config;

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
	string reviewSummary;
	int reviewPercentage, reviewCount;
	string[] developers;
}

StorePage getStorePage(int appID)
{
	StorePage result;
	result.url = "https://store.steampowered.com/app/" ~ appID.text ~ "/";
	try
		result.url = resolveRedirect(result.url);
	catch (Exception e)
	{}

	if (result.url == "https://store.steampowered.com/")
		throw new Exception("No such page (redirect to /)");
	if (result.url.startsWith("https://store.steampowered.com/app/") && result.url.split("/")[4] != appID.text)
		throw new Exception("No such page (redirect to another AppID)");

	auto html = cast(string)getFile(result.url);
	scope(failure) std.file.write("bad.html", html);

	if (html.canFind(`<span class="error">This item is currently unavailable in your region</span>`))
		throw new Exception("This item is currently unavailable in your region");

	result.userTags = html
		.split("\r\n")
		.findSplit!startsWith(["\t\t\tInitAppTagModal( "])[2][0]
		.chomp(",")
		.jsonParse!(UserTag[]);

	result.gameTags = html
		.matchAll(re!`<div class="game_area_details_specs"><div class="icon"><a href="https://store.steampowered.com/search/\?category2=(\d+)&snr=[0-9_]*"><img class="category_icon" src="https://store.edgecast.steamstatic.com/public/images/v6/ico/ico_\w+.png"></a></div><a class="name" href="https://store.steampowered.com/search/\?category2=\d+&snr=[0-9_]*">(.*?)</a></div>`)
		.map!(m => GameTag(m[2], m[1].to!int))
		.array;

	auto reviewSummaries = html
		.matchAll(re!`\t\t<span class="game_review_summary .*?>(.*?)</span>`)
		.map!(m => m[1])
		.array;
	enforce(reviewSummaries.length.isOneOf(
			0,                  // Unreviewable (DLC)
			1,                  // No reviews
			3,                  // No recent reviews
			6,                  // (most pages)
		),
		"Unexpected game_review_summary count");
	result.reviewSummary = reviewSummaries.length > 1 ? reviewSummaries[1] :
		html.canFind("No user reviews") ? "No user reviews" :
		enforce(null, "Can't find reviews");

	list(result.reviewPercentage, result.reviewCount) = html
		.matchFirst(re!`"(\d+)% of the ([0-9,]*) user reviews for this game are positive\."`)
		.I!(m => tuple(m[1].length ? m[1].to!int : 0, m[2].length ? m[2].replace(",", "").to!int : 0));

	result.developers = html
		.matchAll(re!`<a href="https://store\.steampowered\.com/search/\?developer=.*?">(.*?)</a>`)
		.map!(m => m[1])
		.array
		.sort
		.uniq
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
		chain(
			getConfig().cookies
			.split(";")
			.map!(s => s.findSplit("="))
			.map!(p => tuple(p[0], p[2])),
			only(
				tuple("birthtime", format!"%d"(birthday.toUnixTime)),
				tuple("lastagecheckage", format!"%2d-%s-%d"(
					birthday.day,
					MonthLongNames[birthday.month-1],
					birthday.year,
				)),
				tuple("mature_content", "1"),
				tuple("wants_mature_content", "1"),
			)
		)
		.assocArray
		.byKeyValue
		.map!(kv => format!"%s=%s"(kv.key, kv.value))
		.join("; ")
	);
}
