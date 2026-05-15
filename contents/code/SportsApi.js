/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

.pragma library
.import "providers/ProviderCatalog.js" as ProviderCatalog

const REQUEST_TIMEOUT_MS = 12000;
const SOFASCORE_API_BASE_URL = "https://api.sofascore.com/api/v1";
const THESPORTSDB_API_BASE_URL = "https://www.thesportsdb.com/api/v1/json/3";

const SOFASCORE_TOURNAMENTS = {
    "bulgarian-first-league": { id: 247, label: "Bulgarian First League" }
};

const THESPORTSDB_LEAGUES = {
    "bulgarian-first-league": { id: "4626", label: "Bulgarian First League" }
};

function fetchLiveScores(options, onSuccess, onError) {
    const sports = normalizeSports(options.sports);

    if (sports.length === 0) {
        onSuccess([]);
        return;
    }

    const provider = "sportscore";
    fetchProviderMatches(provider, "live", Object.assign({}, options, {
        provider,
        baseUrl: ProviderCatalog.defaultBaseUrl(provider)
    }), onSuccess, onError);
}

function fetchLeagueTable(options, onSuccess, onError) {
    const provider = "sportscore";
    fetchProviderTable(provider, Object.assign({}, options, {
        provider,
        baseUrl: ProviderCatalog.defaultBaseUrl(provider)
    }), onSuccess, onError);
}

function fetchScoresFixtures(options, onSuccess, onError) {
    const provider = "sportscore";

    function finish(fixtures) {
        if (fixtures.length > 0) {
            onSuccess(fixtures);
            return;
        }

        fetchFallbackFixtures(options, onSuccess, onError);
    }

    function fail(message) {
        fetchFallbackFixtures(options, onSuccess, fallbackMessage => {
            onError(fallbackMessage || message);
        });
    }

    if (canFetchSportScoreTeamFixtures(options)) {
        fetchSportScoreTeamFixtures(options, fixtures => {
            if (fixtures.length > 0) {
                onSuccess(fixtures);
                return;
            }

            fetchSportScoreCompetitionFixturesOrProvider(options, provider, finish, fail);
        }, () => {
            fetchSportScoreCompetitionFixturesOrProvider(options, provider, finish, fail);
        });
        return;
    }

    fetchSportScoreCompetitionFixturesOrProvider(options, provider, finish, fail);
}

function fetchSportScoreCompetitionFixturesOrProvider(options, provider, onSuccess, onError) {
    if (canFetchSportScoreCompetitionFixtures(options)) {
        fetchSportScoreCompetitionFixtures(options, fixtures => {
            if (fixtures.length > 0) {
                onSuccess(fixtures);
                return;
            }

            fetchProviderMatches(provider, "fixtures", Object.assign({}, options, {
                provider,
                baseUrl: ProviderCatalog.defaultBaseUrl(provider)
            }), onSuccess, onError);
        }, () => {
            fetchProviderMatches(provider, "fixtures", Object.assign({}, options, {
                provider,
                baseUrl: ProviderCatalog.defaultBaseUrl(provider)
            }), onSuccess, onError);
        });
        return;
    }

    fetchProviderMatches(provider, "fixtures", Object.assign({}, options, {
        provider,
        baseUrl: ProviderCatalog.defaultBaseUrl(provider)
    }), onSuccess, onError);
}

function fetchLeagueForm(options, onSuccess, onError) {
    const sport = normalizeSports(options.sports)[0] || "football";

    function canUseSportScore() {
        const league = String(options.league || "").trim().toUpperCase();
        const rows = Array.isArray(options.tableRows) ? options.tableRows : [];
        return (sport === "football" || sport === "soccer") && ProviderCatalog.sportScoreSlug(league).length > 0 && rows.length > 0;
    }

    function fetchFromFixtures() {
        fetchScoresFixtures(options, matches => {
            onSuccess(formByTeam(matches));
        }, onError);
    }

    function fetchFromSportScore() {
        fetchSportScoreTeamForms(options, onSuccess, fetchFromFixtures);
    }

    if (canUseSportScore()) {
        fetchFromSportScore();
        return;
    }

    fetchFromFixtures();
}

function fetchSportScoreTeamForms(options, onSuccess, onError) {
    const sport = normalizeSports(options.sports)[0] || "football";
    const league = String(options.league || "").trim().toUpperCase();
    const rows = Array.isArray(options.tableRows) ? options.tableRows.map(row => {
        const copy = Object.assign({}, row);
        copy.teamSlug = sportScoreTeamSlug(row);
        return copy;
    }).filter(row => stringValue(row.teamSlug).length > 0 && stringValue(row.team).length > 0) : [];
    if ((sport !== "football" && sport !== "soccer") || ProviderCatalog.sportScoreSlug(league).length === 0 || rows.length === 0) {
        onError("SportScore team form is not available for this selection.");
        return;
    }

    let pending = rows.length;
    let forms = {};
    let errors = [];
    const baseUrl = stripTrailingSlash(ProviderCatalog.defaultBaseUrl("sportscore"));

    rows.forEach(row => {
        const url = `${baseUrl}/team/?sport=football&slug=${encodeURIComponent(row.teamSlug)}&limit=5`;
        requestJson(url, payload => {
            const form = sportScoreTeamForm(payload, row.team);
            if (form.length > 0)
                forms[normalizedText(row.team)] = form;

            pending -= 1;
            if (pending === 0) {
                if (Object.keys(forms).length > 0) {
                    onSuccess(forms);
                } else {
                    onError(errors.join(", ") || "SportScore returned no team form.");
                }
            }
        }, message => {
            if (!isHttpNotFound(message))
                errors.push(`${row.team}: ${message}`);

            pending -= 1;
            if (pending === 0) {
                if (Object.keys(forms).length > 0) {
                    onSuccess(forms);
                } else {
                    onError(errors.join(", "));
                }
            }
        });
    });
}

function canFetchSportScoreTeamFixtures(options) {
    const sport = normalizeSports(options.sports)[0] || "football";
    const league = ProviderCatalog.sportScoreSlug(options.league);
    const rows = Array.isArray(options.tableRows) ? options.tableRows : [];
    return (sport === "football" || sport === "soccer") && league.length > 0 && rows.some(row => sportScoreTeamSlug(row).length > 0);
}

function fetchSportScoreTeamFixtures(options, onSuccess, onError) {
    const rows = (Array.isArray(options.tableRows) ? options.tableRows : []).map(row => {
        const copy = Object.assign({}, row);
        copy.teamSlug = sportScoreTeamSlug(row);
        return copy;
    }).filter(row => stringValue(row.teamSlug).length > 0 && stringValue(row.team).length > 0).slice(0, 24);

    if (rows.length === 0) {
        onSuccess([]);
        return;
    }

    let pending = rows.length;
    let matches = [];
    let errors = [];
    const baseUrl = stripTrailingSlash(ProviderCatalog.defaultBaseUrl("sportscore"));

    rows.forEach(row => {
        const url = `${baseUrl}/team/?sport=football&slug=${encodeURIComponent(row.teamSlug)}&limit=20&src=sports-widget-for-plasma`;
        requestJson(url, payload => {
            matches = matches.concat(ProviderCatalog.normalizeFixtures("sportscore", payload, "football"));
            pending -= 1;
            if (pending === 0)
                finishTeamFixtures(matches, errors, options, onSuccess, onError);
        }, message => {
            if (!isHttpNotFound(message))
                errors.push(`${row.team}: ${message}`);

            pending -= 1;
            if (pending === 0)
                finishTeamFixtures(matches, errors, options, onSuccess, onError);
        });
    });
}

function finishTeamFixtures(matches, errors, options, onSuccess, onError) {
    const rows = dedupeMatches(filterMatchesForSelection(matches, options));
    if (rows.length > 0 || errors.length === 0) {
        onSuccess(sortMatches(rows));
    } else {
        onError(errors.join(", "));
    }
}

function canFetchSportScoreCompetitionFixtures(options) {
    const sport = normalizeSports(options.sports)[0] || "football";
    const country = String(options.country || "").trim();
    const league = ProviderCatalog.sportScoreSlug(options.league);
    return (sport === "football" || sport === "soccer") && country.length > 0 && league.length > 0;
}

function fetchSportScoreCompetitionFixtures(options, onSuccess, onError) {
    const country = String(options.country || "england").trim().toLowerCase();
    const league = ProviderCatalog.sportScoreSlug(options.league);
    const leagueLabel = ProviderCatalog.leagueLabel(options.league);
    const sourceUrl = country === "world" ? "https://sportscore.com/football/competitions/" : `https://sportscore.com/football/country/${encodeURIComponent(country)}/`;

    requestText(sourceUrl, html => {
        const path = sportScoreCompetitionPath(html, country, league);
        if (path.length === 0) {
            onSuccess([]);
            return;
        }

        requestText(`https://sportscore.com${path}`, page => {
            onSuccess(normalizeSportScoreFixturePage(page, leagueLabel));
        }, onError);
    }, onError);
}

function fetchFallbackFixtures(options, onSuccess, onError) {
    let errors = [];

    function remember(message) {
        if (String(message || "").length > 0)
            errors.push(message);
    }

    function fetchFromTheSportsDB() {
        if (!canFetchTheSportsDBFixtures(options)) {
            onError(errors.join(", ") || "No fallback fixture provider is available for this league.");
            return;
        }

        fetchTheSportsDBFixtures(options, fixtures => {
            if (fixtures.length > 0) {
                onSuccess(fixtures);
                return;
            }

            onError(errors.join(", ") || "Fallback providers returned no fixtures.");
        }, message => {
            remember(message);
            onError(errors.join(", "));
        });
    }

    if (canFetchSofaScoreFixtures(options)) {
        fetchSofaScoreFixtures(options, fixtures => {
            if (fixtures.length > 0) {
                onSuccess(fixtures);
                return;
            }

            fetchFromTheSportsDB();
        }, message => {
            remember(message);
            fetchFromTheSportsDB();
        });
        return;
    }

    fetchFromTheSportsDB();
}

function canFetchSofaScoreFixtures(options) {
    return fallbackLeague(SOFASCORE_TOURNAMENTS, options).id > 0 && isFootballSelection(options);
}

function fetchSofaScoreFixtures(options, onSuccess, onError) {
    const league = fallbackLeague(SOFASCORE_TOURNAMENTS, options);
    requestJson(`${SOFASCORE_API_BASE_URL}/unique-tournament/${league.id}/seasons`, payload => {
        const season = arrayValue(payload && payload.seasons)[0];
        const seasonId = numberValue(season && season.id);
        if (seasonId <= 0) {
            onSuccess([]);
            return;
        }

        fetchSofaScoreFixturePage(league, seasonId, 0, [], onSuccess, onError);
    }, onError);
}

function fetchSofaScoreFixturePage(league, seasonId, page, matches, onSuccess, onError) {
    const url = `${SOFASCORE_API_BASE_URL}/unique-tournament/${league.id}/season/${seasonId}/events/next/${page}`;
    requestJson(url, payload => {
        const rows = matches.concat(arrayValue(payload && payload.events).map(event => normalizeSofaScoreFixture(event, league)).filter(hasTeams));
        if (payload && payload.hasNextPage && page < 2) {
            fetchSofaScoreFixturePage(league, seasonId, page + 1, rows, onSuccess, onError);
            return;
        }

        onSuccess(sortMatches(dedupeMatches(rows)));
    }, onError);
}

function normalizeSofaScoreFixture(event, league) {
    const timestamp = numberValue(event && event.startTimestamp) * 1000;
    const homeTeam = event && event.homeTeam ? event.homeTeam : {};
    const awayTeam = event && event.awayTeam ? event.awayTeam : {};
    const status = event && event.status ? event.status : {};
    const homeScore = event && event.homeScore ? event.homeScore : {};
    const awayScore = event && event.awayScore ? event.awayScore : {};
    return {
        id: "sofascore-" + stringValue(event && event.id),
        sport: "football",
        league: league.label,
        homeTeam: stringValue(homeTeam.shortName || homeTeam.name),
        awayTeam: stringValue(awayTeam.shortName || awayTeam.name),
        homeScore: sofaScoreDisplayScore(homeScore),
        awayScore: sofaScoreDisplayScore(awayScore),
        status: statusLabel(status.description || status.type),
        minute: "",
        startTime: timestamp > 0 ? formatStartTime(timestamp) : "",
        timestamp,
        matchday: event && event.roundInfo && event.roundInfo.round ? "Round " + event.roundInfo.round : "",
        stadium: sofaScoreStadium(event && event.venue),
        homeBadge: sofaScoreTeamImage(homeTeam.id),
        awayBadge: sofaScoreTeamImage(awayTeam.id),
        poster: "",
        popular: false
    };
}

function sofaScoreDisplayScore(score) {
    if (score === undefined || score === null)
        return "";

    if (score.display !== undefined && score.display !== null)
        return stringValue(score.display);

    if (score.current !== undefined && score.current !== null)
        return stringValue(score.current);

    return "";
}

function sofaScoreStadium(venue) {
    if (!venue)
        return "";

    return stringValue(venue.stadium && venue.stadium.name) || stringValue(venue.name);
}

function sofaScoreTeamImage(teamId) {
    const id = numberValue(teamId);
    return id > 0 ? `${SOFASCORE_API_BASE_URL}/team/${id}/image` : "";
}

function canFetchTheSportsDBFixtures(options) {
    return stringValue(fallbackLeague(THESPORTSDB_LEAGUES, options).id).length > 0 && isFootballSelection(options);
}

function fetchTheSportsDBFixtures(options, onSuccess, onError) {
    const league = fallbackLeague(THESPORTSDB_LEAGUES, options);
    requestJson(`${THESPORTSDB_API_BASE_URL}/eventsnextleague.php?id=${encodeURIComponent(league.id)}`, payload => {
        onSuccess(sortMatches(dedupeMatches(arrayValue(payload && payload.events).map(event => normalizeTheSportsDBFixture(event, league)).filter(hasTeams))));
    }, onError);
}

function normalizeTheSportsDBFixture(event, league) {
    const timestamp = Date.parse(event && event.strTimestamp ? event.strTimestamp + "Z" : "");
    return {
        id: "thesportsdb-" + stringValue(event && event.idEvent),
        sport: "football",
        league: stringValue(event && event.strLeague) || league.label,
        homeTeam: stringValue(event && event.strHomeTeam),
        awayTeam: stringValue(event && event.strAwayTeam),
        homeScore: stringValue(event && event.intHomeScore),
        awayScore: stringValue(event && event.intAwayScore),
        status: statusLabel(event && event.strStatus),
        minute: "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: event && event.intRound ? "Round " + event.intRound : "",
        stadium: stringValue(event && event.strVenue),
        homeBadge: stringValue(event && event.strHomeTeamBadge),
        awayBadge: stringValue(event && event.strAwayTeamBadge),
        poster: stringValue(event && (event.strPoster || event.strThumb)),
        popular: false
    };
}

function fallbackLeague(map, options) {
    const slug = ProviderCatalog.sportScoreSlug(options.league);
    return map[slug] || {};
}

function isFootballSelection(options) {
    const sport = normalizeSports(options.sports)[0] || "football";
    return sport === "football" || sport === "soccer";
}

function fetchMatchStats(options, onSuccess, onError) {
    onSuccess([]);
}

function fetchLegacyLiveScores(options, onSuccess, onError) {
    fetchLiveScores(options, onSuccess, onError);
}

function fetchLegacyLeagueTable(options, onSuccess, onError) {
    fetchLeagueTable(options, onSuccess, onError);
}

function fetchLegacyScoresFixtures(options, onSuccess, onError) {
    fetchScoresFixtures(options, onSuccess, onError);
}

function fetchSportScoreTable(options, onSuccess, onError) {
    const league = String(options.league || "PL").trim().toUpperCase();
    if (ProviderCatalog.sportScoreSlug(league).length === 0) {
        onSuccess([]);
        return;
    }

    fetchProviderTable("sportscore", withProvider(options, "sportscore"), onSuccess, onError);
}

function withProvider(options, provider) {
    const copy = Object.assign({}, options);
    copy.provider = provider;
    copy.baseUrl = ProviderCatalog.defaultBaseUrl("sportscore");
    return copy;
}

function fetchProviderMatches(provider, type, options, onSuccess, onError) {
    if (missingProviderKey(provider, options, onError))
        return;

    const requests = type === "fixtures" ? ProviderCatalog.fixtureRequests(provider, options) : ProviderCatalog.liveRequests(provider, options);
    fetchProviderRequests(provider, requests, options, (payload, item) => {
        return type === "fixtures" ? ProviderCatalog.normalizeFixtures(provider, payload, item.sport) : ProviderCatalog.normalizeMatches(provider, payload, item.sport);
    }, matches => {
        onSuccess(sortMatches(filterMatchesForSelection(matches, options)));
    }, onError);
}

function fetchProviderTable(provider, options, onSuccess, onError) {
    if (missingProviderKey(provider, options, onError))
        return;

    const requests = ProviderCatalog.tableRequests(provider, options);
    fetchProviderRequests(provider, requests, options, payload => {
        return ProviderCatalog.normalizeTable(provider, payload);
    }, onSuccess, onError);
}

function fetchProviderRequests(provider, requests, options, normalize, onSuccess, onError) {
    if (requests.length === 0) {
        onSuccess([]);
        return;
    }

    let pending = requests.length;
    let rows = [];
    let errors = [];
    const headers = ProviderCatalog.headers(provider, options.apiKey, options.baseUrl);

    requests.forEach(item => {
        requestJsonWithHeaders(item.url, headers, payload => {
            rows = rows.concat(normalize(payload, item));
            pending -= 1;
            if (pending === 0) {
                if (rows.length > 0 || errors.length === 0) {
                    onSuccess(rows);
                } else {
                    onError(errors.join(", "));
                }
            }
        }, message => {
            if (!item.optional || !isHttpNotFound(message))
                errors.push(`${ProviderCatalog.displayName(provider)}: ${message}`);

            pending -= 1;
            if (pending === 0) {
                if (rows.length > 0 || errors.length === 0) {
                    onSuccess(rows);
                } else {
                    onError(errors.join(", "));
                }
            }
        });
    });
}

function isHttpNotFound(message) {
    return String(message || "").indexOf("HTTP 404") >= 0;
}

function missingProviderKey(provider, options, onError) {
    if (!ProviderCatalog.requiresApiKey(provider))
        return false;

    if (String(options.apiKey || "").trim().length > 0)
        return false;

    onError(`${ProviderCatalog.displayName(provider)} requires an API key.`);
    return true;
}

function requestJson(url, onSuccess, onError) {
    requestJsonWithHeaders(url, {}, onSuccess, onError);
}

function requestJsonWithHeaders(url, headers, onSuccess, onError) {
    requestTextWithHeaders(url, headers, responseText => {
        try {
            onSuccess(JSON.parse(responseText));
        } catch (error) {
            onError(String(error));
        }
    }, onError);
}

function requestText(url, onSuccess, onError) {
    requestTextWithHeaders(url, { "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" }, onSuccess, onError);
}

function requestTextWithHeaders(url, headers, onSuccess, onError) {
    const request = new XMLHttpRequest();
    let completed = false;

    function finish(errorMessage) {
        if (completed)
            return;

        completed = true;
        if (errorMessage.length > 0) {
            onError(errorMessage);
            return;
        }

        if (request.status >= 200 && request.status < 300) {
            onSuccess(request.responseText);
        } else {
            onError(`HTTP ${request.status}`);
        }
    }

    request.open("GET", url);
    request.timeout = REQUEST_TIMEOUT_MS;
    if (!hasHeader(headers, "Accept"))
        request.setRequestHeader("Accept", "application/json");

    Object.keys(headers || {}).forEach(header => {
        if (headers[header] !== undefined && headers[header] !== null && String(headers[header]).length > 0) {
            request.setRequestHeader(header, headers[header]);
        }
    });
    request.onreadystatechange = function() {
        if (request.readyState !== XMLHttpRequest.DONE) {
            return;
        }

        finish("");
    };
    request.ontimeout = function() {
        finish("request timed out");
    };
    request.onerror = function() {
        finish("network error");
    };
    request.send();
}

function hasHeader(headers, headerName) {
    const normalized = String(headerName || "").toLowerCase();
    return Object.keys(headers || {}).some(header => header.toLowerCase() === normalized);
}

function sportScoreCompetitionPath(html, country, league) {
    const escapedCountry = escapeRegExp(country);
    const escapedLeague = escapeRegExp(league);
    const exact = new RegExp(`href="(/football/competition/${escapedCountry}/${escapedLeague}/[^"]+/)"`);
    let match = exact.exec(html);
    if (match)
        return match[1];

    const fallback = new RegExp(`href="(/football/competition/[^/]+/${escapedLeague}/[^"]+/)"`);
    match = fallback.exec(html);
    return match ? match[1] : "";
}

function normalizeSportScoreFixturePage(html, leagueLabel) {
    const lists = sportScoreJsonLdLists(html);
    let selected = null;
    for (let index = 0; index < lists.length; index += 1) {
        const name = normalizedText(lists[index].name);
        if (name.indexOf("upcoming fixtures") >= 0) {
            selected = lists[index];
            break;
        }
    }

    if (!selected)
        return [];

    const listItems = arrayValue(selected.itemListElement);
    return listItems.map(item => normalizeSchemaFixture(item && item.item, leagueLabel))
        .filter(hasTeams)
        .sort((left, right) => numberValue(left.timestamp) - numberValue(right.timestamp));
}

function sportScoreJsonLdLists(html) {
    let result = [];
    const pattern = /<script type="application\/ld\+json">([\s\S]*?)<\/script>/g;
    let match = pattern.exec(html);
    while (match) {
        try {
            collectJsonLdLists(JSON.parse(match[1]), result);
        } catch (error) {
        }
        match = pattern.exec(html);
    }
    return result;
}

function collectJsonLdLists(value, result) {
    if (!value)
        return;

    if (Array.isArray(value)) {
        value.forEach(item => collectJsonLdLists(item, result));
        return;
    }

    if (typeof value !== "object")
        return;

    if (value["@type"] === "ItemList")
        result.push(value);

    collectJsonLdLists(value["@graph"], result);
}

function normalizeSchemaFixture(event, leagueLabel) {
    if (!event)
        return {};

    const timestamp = Date.parse(event.startDate || "");
    const images = arrayValue(event.image);
    return {
        id: stringValue(event["@id"] || event.url),
        sport: "football",
        league: leagueLabel,
        homeTeam: schemaTeamName(event.homeTeam),
        awayTeam: schemaTeamName(event.awayTeam),
        homeScore: "",
        awayScore: "",
        status: "Upcoming",
        minute: "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : stringValue(event.startDate),
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: "",
        homeBadge: stringValue(images[0]),
        awayBadge: stringValue(images[1]),
        poster: "",
        popular: false
    };
}

function schemaTeamName(team) {
    if (!team)
        return "";
    if (typeof team === "string")
        return team;
    return stringValue(team.name);
}

function escapeRegExp(value) {
    return String(value || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function normalizeSports(value) {
    if (Array.isArray(value)) {
        return value.map(sport => String(sport).trim().toLowerCase()).filter(Boolean);
    }

    return String(value || "")
        .split(",")
        .map(sport => sport.trim().toLowerCase())
        .filter(Boolean);
}

function demoMatches() {
    return [
        {
            sport: "football",
            league: "Premier League",
            homeTeam: "Arsenal",
            awayTeam: "Chelsea",
            homeScore: "2",
            awayScore: "1",
            status: "Live",
            minute: "72'",
            startTime: "",
            homeBadge: "",
            awayBadge: "",
            poster: "",
            popular: true
        },
        {
            sport: "basketball",
            league: "NBA",
            homeTeam: "Boston Celtics",
            awayTeam: "New York Knicks",
            homeScore: "88",
            awayScore: "83",
            status: "Q4",
            minute: "08:14",
            startTime: "",
            homeBadge: "",
            awayBadge: "",
            poster: "",
            popular: true
        },
        {
            sport: "hockey",
            league: "NHL",
            homeTeam: "New York Rangers",
            awayTeam: "Boston Bruins",
            homeScore: "1",
            awayScore: "1",
            status: "2nd",
            minute: "12:31",
            startTime: "",
            homeBadge: "",
            awayBadge: "",
            poster: "",
            popular: false
        }
    ];
}

function demoTable() {
    return [
        { position: 1, team: "Arsenal", played: 36, won: 24, draw: 7, lost: 5, goalsFor: 68, goalsAgainst: 26, points: 79, goalDifference: 42, form: "W,L,L,W,W", crest: "" },
        { position: 2, team: "Man City", played: 35, won: 22, draw: 8, lost: 5, goalsFor: 72, goalsAgainst: 32, points: 74, goalDifference: 40, form: "W,D,W,W,W", crest: "" },
        { position: 3, team: "Man United", played: 36, won: 18, draw: 11, lost: 7, goalsFor: 63, goalsAgainst: 48, points: 65, goalDifference: 15, form: "D,L,W,W,W", crest: "" },
        { position: 4, team: "Liverpool", played: 36, won: 17, draw: 8, lost: 11, goalsFor: 60, goalsAgainst: 48, points: 59, goalDifference: 12, form: "D,L,W,W,W", crest: "" },
        { position: 5, team: "Aston Villa", played: 36, won: 17, draw: 8, lost: 11, goalsFor: 50, goalsAgainst: 46, points: 59, goalDifference: 4, form: "D,L,L,W,D", crest: "" },
        { position: 6, team: "Bournemouth", played: 36, won: 13, draw: 16, lost: 7, goalsFor: 56, goalsAgainst: 52, points: 55, goalDifference: 4, form: "D,W,W,D,W", crest: "" },
        { position: 7, team: "Brighton Hove", played: 36, won: 14, draw: 11, lost: 11, goalsFor: 52, goalsAgainst: 42, points: 53, goalDifference: 10, form: "W,W,D,W,L", crest: "" },
        { position: 8, team: "Brentford", played: 36, won: 14, draw: 9, lost: 13, goalsFor: 52, goalsAgainst: 49, points: 51, goalDifference: 3, form: "D,D,D,L,W", crest: "" },
        { position: 9, team: "Chelsea", played: 36, won: 13, draw: 10, lost: 13, goalsFor: 55, goalsAgainst: 49, points: 49, goalDifference: 6, form: "L,L,L,L,L", crest: "" },
        { position: 10, team: "Everton", played: 36, won: 13, draw: 10, lost: 13, goalsFor: 46, goalsAgainst: 46, points: 49, goalDifference: 0, form: "W,D,L,L,D", crest: "" },
        { position: 11, team: "Fulham", played: 36, won: 14, draw: 6, lost: 16, goalsFor: 44, goalsAgainst: 50, points: 48, goalDifference: -6, form: "W,L,D,W,L", crest: "" },
        { position: 12, team: "Sunderland", played: 36, won: 12, draw: 12, lost: 12, goalsFor: 37, goalsAgainst: 46, points: 48, goalDifference: -9, form: "W,W,D,L,L", crest: "" },
        { position: 13, team: "Newcastle", played: 36, won: 13, draw: 7, lost: 16, goalsFor: 50, goalsAgainst: 52, points: 46, goalDifference: -2, form: "L,W,D,L,W", crest: "" },
        { position: 14, team: "Leeds United", played: 36, won: 10, draw: 14, lost: 12, goalsFor: 48, goalsAgainst: 53, points: 44, goalDifference: -5, form: "D,W,L,D,W", crest: "" },
        { position: 15, team: "Crystal Palace", played: 35, won: 11, draw: 11, lost: 13, goalsFor: 38, goalsAgainst: 44, points: 44, goalDifference: -6, form: "D,W,L,W,L", crest: "" },
        { position: 16, team: "Nottingham", played: 36, won: 11, draw: 10, lost: 15, goalsFor: 45, goalsAgainst: 47, points: 43, goalDifference: -2, form: "D,L,W,L,D", crest: "" },
        { position: 17, team: "Tottenham", played: 36, won: 9, draw: 11, lost: 16, goalsFor: 46, goalsAgainst: 55, points: 38, goalDifference: -9, form: "D,W,W,D,L", crest: "" },
        { position: 18, team: "West Ham", played: 36, won: 9, draw: 9, lost: 18, goalsFor: 42, goalsAgainst: 62, points: 36, goalDifference: -20, form: "L,L,W,D,W", crest: "" },
        { position: 19, team: "Burnley", played: 36, won: 4, draw: 9, lost: 23, goalsFor: 37, goalsAgainst: 73, points: 21, goalDifference: -36, form: "D,L,L,L,L", crest: "" },
        { position: 20, team: "Wolverhampton", played: 36, won: 3, draw: 9, lost: 24, goalsFor: 25, goalsAgainst: 66, points: 18, goalDifference: -41, form: "L,D,L,L,L", crest: "" }
    ];
}

function demoFixtures() {
    return [
        { homeTeam: "Liverpool", awayTeam: "Chelsea", homeScore: "1", awayScore: "1", status: "Finished", startTime: "09.05 14:30", matchday: "MD 36", homeBadge: "", awayBadge: "" },
        { homeTeam: "Manchester City", awayTeam: "Brentford", homeScore: "3", awayScore: "0", status: "Finished", startTime: "09.05 19:30", matchday: "MD 36", homeBadge: "", awayBadge: "" },
        { homeTeam: "Tottenham", awayTeam: "Leeds United", homeScore: "1", awayScore: "1", status: "Finished", startTime: "11.05 22:00", matchday: "MD 36", homeBadge: "", awayBadge: "" }
    ];
}

function normalizeSportScoreMatch(match, sport) {
    const timestamp = Date.parse(match.time || match.date || "");
    return {
        sport: sport || "football",
        league: stringValue(match.competition),
        homeTeam: stringValue(match.home),
        awayTeam: stringValue(match.away),
        homeScore: stringValue(match.home_score),
        awayScore: stringValue(match.away_score),
        status: statusLabel(match.status_text || match.status),
        minute: "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        homeBadge: stringValue(match.home_logo),
        awayBadge: stringValue(match.away_logo),
        popular: false
    };
}

function sportScoreTeamForm(payload, teamName) {
    const scopedTeamName = stringValue(payload && payload.team && payload.team.name) || teamName;
    const matches = arrayValue(payload && payload.matches)
        .map(match => normalizeSportScoreMatch(match, "football"))
        .filter(match => match.status === "Finished" && Number.isFinite(Number(match.homeScore)) && Number.isFinite(Number(match.awayScore)))
        .slice(0, 5);
    let form = [];

    matches.forEach(match => {
        const home = sameTeamName(match.homeTeam, scopedTeamName) || sameTeamName(match.homeTeam, teamName);
        const away = sameTeamName(match.awayTeam, scopedTeamName) || sameTeamName(match.awayTeam, teamName);
        if (!home && !away)
            return;

        const goalsFor = home ? numberValue(match.homeScore) : numberValue(match.awayScore);
        const goalsAgainst = home ? numberValue(match.awayScore) : numberValue(match.homeScore);
        if (goalsFor > goalsAgainst) {
            form.push("W");
        } else if (goalsFor < goalsAgainst) {
            form.push("L");
        } else {
            form.push("D");
        }
    });

    return form.join(",");
}

function sportScoreTeamSlug(row) {
    const explicit = stringValue(row && row.teamSlug).trim();
    if (explicit.length > 0)
        return explicit;

    return normalizedText(row && row.team)
        .replace(/&/g, "and")
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "");
}

function dedupeMatches(matches) {
    let seen = {};
    let result = [];
    (Array.isArray(matches) ? matches : []).forEach(match => {
        const key = [
            normalizedText(match.league),
            normalizedText(match.homeTeam),
            normalizedText(match.awayTeam),
            String(match.timestamp || match.startTime || "")
        ].join("|");
        if (seen[key])
            return;

        seen[key] = true;
        result.push(match);
    });
    return result;
}

function sortMatches(matches) {
    return matches.sort((left, right) => {
        if (left.status === "Live" && right.status !== "Live") {
            return -1;
        }

        if (right.status === "Live" && left.status !== "Live") {
            return 1;
        }

        if (left.timestamp > 0 && right.timestamp > 0 && left.timestamp !== right.timestamp) {
            return left.timestamp - right.timestamp;
        }

        if (left.sport === right.sport) {
            return left.league.localeCompare(right.league) || left.homeTeam.localeCompare(right.homeTeam);
        }

        return left.sport.localeCompare(right.sport);
    });
}

function filterMatchesForSelection(matches, options) {
    const sport = normalizeSports(options.sports)[0] || "football";
    if (sport !== "football" && sport !== "soccer")
        return matches;

    const league = ProviderCatalog.sportScoreSlug(options.league);
    if (league.length === 0)
        return matches;

    const label = ProviderCatalog.leagueLabel(options.league);
    const candidates = [league, label].map(normalizedText).filter(value => value.length > 0);
    if (candidates.length === 0)
        return matches;

    return matches.filter(match => {
        const matchLeague = normalizedText(match.league);
        if (matchLeague.length === 0)
            return true;

        for (let index = 0; index < candidates.length; index += 1) {
            if (matchLeague === candidates[index] || matchLeague.indexOf(candidates[index]) >= 0 || candidates[index].indexOf(matchLeague) >= 0)
                return true;
        }
        return false;
    });
}

function formByTeam(matches) {
    let result = {};
    const finished = (matches || []).filter(match => match.status === "Finished" && Number.isFinite(Number(match.homeScore)) && Number.isFinite(Number(match.awayScore)))
        .sort((left, right) => numberValue(left.timestamp) - numberValue(right.timestamp));

    function append(teamName, value) {
        const key = normalizedText(teamName);
        if (key.length === 0)
            return;

        if (!result[key])
            result[key] = [];

        result[key].push(value);
    }

    function appendAll(teamName, aliases, value) {
        let seen = {};
        const names = [teamName].concat(Array.isArray(aliases) ? aliases : []);
        names.forEach(name => {
            const key = normalizedText(name);
            if (key.length === 0 || seen[key])
                return;

            seen[key] = true;
            append(name, value);
        });
    }

    finished.forEach(match => {
        const homeGoals = numberValue(match.homeScore);
        const awayGoals = numberValue(match.awayScore);
        if (homeGoals > awayGoals) {
            appendAll(match.homeTeam, match.homeTeamAliases, "W");
            appendAll(match.awayTeam, match.awayTeamAliases, "L");
        } else if (homeGoals < awayGoals) {
            appendAll(match.homeTeam, match.homeTeamAliases, "L");
            appendAll(match.awayTeam, match.awayTeamAliases, "W");
        } else {
            appendAll(match.homeTeam, match.homeTeamAliases, "D");
            appendAll(match.awayTeam, match.awayTeamAliases, "D");
        }
    });

    Object.keys(result).forEach(key => {
        result[key] = result[key].slice(-5).join(",");
    });
    return result;
}

function formForTeam(formMap, teamName) {
    const key = normalizedText(teamName);
    if (formMap[key])
        return formMap[key];

    const compact = compactTeamName(teamName);
    const alias = teamAliasKey(teamName);
    const keys = Object.keys(formMap || {});
    for (let index = 0; index < keys.length; index += 1) {
        const itemCompact = compactTeamName(keys[index]);
        const itemAlias = teamAliasKey(keys[index]);
        if (alias.length > 0 && alias === itemAlias)
            return formMap[keys[index]];

        if (compact.length > 0 && itemCompact.indexOf(compact) >= 0)
            return formMap[keys[index]];

        if (compact.length > 0 && compact.indexOf(itemCompact) >= 0)
            return formMap[keys[index]];
    }
    return "";
}

function compactTeamName(value) {
    return normalizedText(value)
        .replace(/\b(fc|cf|afc|ac|sc|ss|ssc|bc|calcio|club|de|la|the)\b/g, "")
        .replace(/[^a-z0-9]+/g, "");
}

function teamAliasKey(value) {
    const compact = compactTeamName(value);
    const aliases = {
        "athletic": "athleticbilbao",
        "athleticbilbao": "athleticbilbao",
        "athleticclub": "athleticbilbao",
        "atleti": "atleticomadrid",
        "atleticomadrid": "atleticomadrid",
        "atletico": "atleticomadrid",
        "atleticodemadrid": "atleticomadrid",
        "barca": "barcelona",
        "barcelona": "barcelona",
        "bayern": "bayernmunich",
        "bayernmunich": "bayernmunich",
        "brighton": "brightonhove",
        "brightonhove": "brightonhove",
        "brightonandhovealbion": "brightonhove",
        "cpalace": "crystalpalace",
        "crystalpalace": "crystalpalace",
        "internazionale": "intermilan",
        "inter": "intermilan",
        "intermilan": "intermilan",
        "manchester": "manchesterunited",
        "manchestercity": "manchestercity",
        "manchesterunited": "manchesterunited",
        "mancity": "manchestercity",
        "manunited": "manchesterunited",
        "manutd": "manchesterunited",
        "milan": "acmilan",
        "acmilan": "acmilan",
        "newcastle": "newcastleunited",
        "newcastleunited": "newcastleunited",
        "nottingham": "nottinghamforest",
        "nottinghamforest": "nottinghamforest",
        "nottmforest": "nottinghamforest",
        "psg": "parissaintgermain",
        "parissaintgermain": "parissaintgermain",
        "real": "realmadrid",
        "realmadrid": "realmadrid",
        "sociedad": "realsociedad",
        "realsociedad": "realsociedad",
        "spurs": "tottenham",
        "tottenham": "tottenham",
        "tottenhamhotspur": "tottenham",
        "westham": "westhamunited",
        "westhamunited": "westhamunited",
        "wolves": "wolverhampton",
        "wolverhampton": "wolverhampton",
        "wolverhamptonwanderers": "wolverhampton"
    };
    return aliases[compact] || compact;
}

function sameTeamName(left, right) {
    const leftText = normalizedText(left);
    const rightText = normalizedText(right);
    if (leftText.length === 0 || rightText.length === 0)
        return false;

    if (leftText === rightText)
        return true;

    const leftAlias = teamAliasKey(left);
    const rightAlias = teamAliasKey(right);
    if (leftAlias.length > 0 && rightAlias.length > 0 && leftAlias === rightAlias)
        return true;

    const leftCompact = compactTeamName(left);
    const rightCompact = compactTeamName(right);
    return leftCompact.length > 0 && rightCompact.length > 0 && (leftCompact.indexOf(rightCompact) >= 0 || rightCompact.indexOf(leftCompact) >= 0);
}

function normalizedText(value) {
    return stripDiacritics(stringValue(value)).toLowerCase().replace(/\s+/g, " ").trim();
}

function stripDiacritics(value) {
    try {
        return String(value).normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    } catch (error) {
        return String(value);
    }
}

function stripTrailingSlash(value) {
    return String(value).replace(/\/+$/, "");
}

function statusLabel(value) {
    const status = stringValue(value).toUpperCase();
    if (status.indexOf("LIVE") >= 0 || status.indexOf("IN_PLAY") >= 0 || status.indexOf("1H") >= 0 || status.indexOf("2H") >= 0)
        return "Live";
    if (status.indexOf("FINISH") >= 0 || status === "ENDED" || status.indexOf("FT") >= 0 || status.indexOf("AET") >= 0)
        return "Finished";
    if (status.indexOf("SCHEDULE") >= 0 || status.indexOf("TIMED") >= 0 || status.indexOf("NOT_STARTED") >= 0 || status.indexOf("NOT STARTED") >= 0 || status.indexOf("UPCOMING") >= 0)
        return "Upcoming";
    return stringValue(value || "Upcoming");
}

function stringValue(value) {
    if (value === undefined || value === null) {
        return "";
    }

    return String(value);
}

function arrayValue(value) {
    return Array.isArray(value) ? value : [];
}

function hasTeams(match) {
    return stringValue(match && match.homeTeam).length > 0 && stringValue(match && match.awayTeam).length > 0;
}

function numberValue(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
}

function formatStartTime(timestamp) {
    const date = new Date(timestamp);
    const today = new Date();
    const tomorrow = new Date();
    tomorrow.setDate(today.getDate() + 1);

    const time = pad(date.getHours()) + ":" + pad(date.getMinutes());
    if (sameDay(date, today)) {
        return time;
    }

    if (sameDay(date, tomorrow)) {
        return "Tomorrow " + time;
    }

    return pad(date.getDate()) + "." + pad(date.getMonth() + 1) + " " + time;
}

function sameDay(left, right) {
    return left.getFullYear() === right.getFullYear() &&
        left.getMonth() === right.getMonth() &&
        left.getDate() === right.getDate();
}

function pad(value) {
    return value < 10 ? "0" + value : String(value);
}
