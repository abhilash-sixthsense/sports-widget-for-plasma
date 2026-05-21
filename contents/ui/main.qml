/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../code/SportsApi.js" as SportsApi
import "../code/SportVisuals.js" as SportVisuals
import "../code/providers/ProviderCatalog.js" as ProviderCatalog
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    property bool loading: false
    property string errorMessage: ""
    property string tableErrorMessage: ""
    property string lastUpdatedText: ""
    property int liveCount: liveMatchesModel.count
    property int scheduleCount: scoresModel.count
    property int tableCount: tableModel.count
    property int recentResultsCount: recentResultsListModel.count
    property bool tableRequestCompleted: false
    property bool currentManualRefresh: false
    property bool liveLoading: false
    property bool schedulesLoading: false
    property bool recentResultsLoading: false
    property bool liveRefreshInFlight: false
    property bool scheduleRequestCompleted: false
    property bool tableScheduleFallbackStarted: false
    property bool recentResultsTableFallbackStarted: false
    property int refreshToken: 0
    property int liveRefreshToken: 0
    property var savedLeagueEntries: savedLeagues()
    property int savedLeagueCount: savedLeagueEntries.length
    property int activeSavedLeagueIndex: normalizedActiveSavedLeagueIndex()
    property var activeLeagueEntry: activeSavedLeague()
    property string selectedCountry: String(activeLeagueEntry.country || "").trim()
    property string selectedLeague: String(activeLeagueEntry.league || "").trim()
    property string favoriteTeam: String(activeLeagueEntry.favoriteTeam || "").trim()
    property string followMode: normalizedFollowMode(activeLeagueEntry)
    property bool followTeamMode: followMode === "team"
    property string providerLabel: providerDisplayName(effectiveProvider())
    property string sourceText: i18nc("@info:status", "No API key required")
    property string primaryMatchText: liveMatchesModel.count > 0 ? liveMatchesModel.get(0).homeTeam + " vs " + liveMatchesModel.get(0).awayTeam : scoresModel.count > 0 ? scoresModel.get(0).homeTeam + " vs " + scoresModel.get(0).awayTeam : root.hasSportSelection() ? i18nc("@info:status", "No scheduled matches") : i18nc("@action:button", "Add a sport")
    property string secondaryMatchText: liveMatchesModel.count > 0 ? liveMatchesModel.get(0).minute || liveMatchesModel.get(0).status : scoresModel.count > 0 ? scoresModel.get(0).startTime || scoresModel.get(0).status : root.hasSportSelection() ? sourceText : i18nc("@info:status", "Open settings to add a league")
    property string panelHeroText: liveMatchesModel.count > 0 ? panelTeamsScoreText(liveMatchesModel.get(0)) : scoresModel.count > 0 ? panelScheduleText(scoresModel.get(0)) : root.hasSportSelection() ? i18nc("@info:status", "No scheduled matches") : i18nc("@action:button", "Add a sport")
    property string panelHeroLiveText: liveMatchesModel.count > 0 ? panelLiveText(liveMatchesModel.get(0)) : ""
    property bool panelHeroLive: liveMatchesModel.count > 0
    property var panelHeroMatch: liveMatchesModel.count > 0 ? liveMatchesModel.get(0) : scoresModel.count > 0 ? scoresModel.get(0) : ({})
    property bool panelHeroShowScore: matchBooleanField(panelHeroMatch, "showScore", liveMatchesModel.count > 0)
    property string panelHeroStatusText: matchStatusText(panelHeroMatch)
    property string panelHeroHomeTeam: matchField(panelHeroMatch, "homeTeam")
    property string panelHeroAwayTeam: matchField(panelHeroMatch, "awayTeam")
    property string panelHeroHomeScore: matchField(panelHeroMatch, "homeScore")
    property string panelHeroAwayScore: matchField(panelHeroMatch, "awayScore")
    property string panelHeroHomeBadge: matchField(panelHeroMatch, "homeBadge")
    property string panelHeroAwayBadge: matchField(panelHeroMatch, "awayBadge")
    property string panelHeroStadium: matchField(panelHeroMatch, "stadium")
    property string selectedSport: String(activeLeagueEntry.sport || "").trim()
    property string selectedLeagueLabel: displayLeagueLabel(activeLeagueEntry)
    property string selectedCountryLabel: displayCountryLabel(activeLeagueEntry)
    property string activeDisplayLabel: followTeamMode ? displayFavoriteTeam(activeLeagueEntry) : selectedLeagueLabel
    property string activeDisplayCountryLabel: followTeamMode ? i18nc("@label", "All competitions") : selectedCountryLabel
    property string activeClubBadge: followTeamMode ? favoriteTeamBadge() : ""
    property string primarySport: liveMatchesModel.count > 0 ? liveMatchesModel.get(0).sport : scoresModel.count > 0 ? scoresModel.get(0).sport : SportVisuals.normalizedSport(selectedSport)
    property int pendingRequests: 0
    property var refreshErrors: []
    property var tableRows: []
    property var primaryTableRows: []
    property var latestLiveMatches: []
    property var latestScheduleMatches: []
    property var latestRecentMatches: []
    property var discoveredTeamCompetitions: []
    property var teamTableOptions: []
    property string selectedTeamTableSlug: ""
    property bool teamTableLoading: false
    property int teamTableRequestToken: 0
    property string pendingScheduleMessage: ""
    readonly property string panelAreaMode: normalizedPanelAreaMode()
    readonly property int panelAreaSize: Math.max(20, Number(Plasmoid.configuration.panelAreaSize || 240))
    readonly property bool panelAreaFill: panelAreaMode === "fill"
    readonly property int compactPanelWidth: panelAreaMode === "manual" ? panelAreaSize : compactRepresentation ? Math.ceil(compactRepresentation.implicitWidth) : Kirigami.Units.gridUnit * 9

    function normalizedPanelAreaMode() {
        const mode = String(Plasmoid.configuration.panelAreaMode || "auto").trim();
        if (mode === "fill" || mode === "manual")
            return mode;

        return "auto";
    }

    function hasSportSelection() {
        return root.savedLeagueCount > 0 && root.selectedSport.length > 0 && root.selectedLeague.length > 0;
    }

    function matchField(match, field) {
        if (!match || match[field] === undefined || match[field] === null)
            return "";

        return String(match[field]).trim();
    }

    function matchBooleanField(match, field, fallback) {
        if (!match || match[field] === undefined || match[field] === null)
            return Boolean(fallback);

        if (typeof match[field] === "boolean")
            return match[field];

        const value = String(match[field]).trim().toLowerCase();
        return value === "true" || value === "1" || value === "yes";
    }

    function savedLeagues() {
        try {
            const parsed = JSON.parse(Plasmoid.configuration.savedLeagues || "[]");
            return Array.isArray(parsed) ? parsed : [];
        } catch (error) {
            return [];
        }
    }

    function normalizedActiveSavedLeagueIndex() {
        const count = root.savedLeagueEntries.length;
        if (count === 0)
            return -1;

        const configured = Number(Plasmoid.configuration.activeSavedLeagueIndex || 0);
        const index = Number.isFinite(configured) ? Math.round(configured) : 0;
        return Math.max(0, Math.min(count - 1, index));
    }

    function activeSavedLeague() {
        if (root.savedLeagueEntries.length === 0)
            return {};

        return root.savedLeagueEntries[root.activeSavedLeagueIndex] || root.savedLeagueEntries[0] || {};
    }

    function displayLeagueLabel(entry) {
        entry = entry || {};
        return String(entry.customLeagueLabel || entry.leagueLabel || ProviderCatalog.leagueLabel(entry.league) || entry.league || "").trim();
    }

    function displayCountryLabel(entry) {
        entry = entry || {};
        return String(entry.customCountryLabel || entry.countryLabel || entry.country || "").trim();
    }

    function displayFavoriteTeam(entry) {
        entry = entry || {};
        return String(entry.customFavoriteTeamLabel || entry.favoriteTeam || "").trim();
    }

    function badgeFromMatch(match) {
        if (!match)
            return "";

        if (isFavoriteMatch({"team": match.homeTeam || ""}))
            return String(match.homeBadge || "").trim();

        if (isFavoriteMatch({"team": match.awayTeam || ""}))
            return String(match.awayBadge || "").trim();

        return "";
    }

    function favoriteTeamBadge() {
        const rowSources = [root.primaryTableRows, root.tableRows];
        for (let sourceIndex = 0; sourceIndex < rowSources.length; sourceIndex += 1) {
            const rows = Array.isArray(rowSources[sourceIndex]) ? rowSources[sourceIndex] : [];
            for (let index = 0; index < rows.length; index += 1) {
                const row = rows[index] || {};
                if (isFavoriteMatch({"team": row.team || ""}) && String(row.crest || "").trim().length > 0)
                    return String(row.crest).trim();
            }
        }

        const matchSources = [root.latestLiveMatches, root.latestScheduleMatches, root.latestRecentMatches];
        for (let sourceIndex = 0; sourceIndex < matchSources.length; sourceIndex += 1) {
            const matches = Array.isArray(matchSources[sourceIndex]) ? matchSources[sourceIndex] : [];
            for (let index = 0; index < matches.length; index += 1) {
                const badge = root.badgeFromMatch(matches[index]);
                if (badge.length > 0)
                    return badge;
            }
        }

        for (let index = 0; index < root.discoveredTeamCompetitions.length; index += 1) {
            const badge = String(root.discoveredTeamCompetitions[index] && root.discoveredTeamCompetitions[index].teamBadge || "").trim();
            if (badge.length > 0)
                return badge;
        }

        return "";
    }

    function titleFromSlug(slug) {
        return String(slug || "")
            .replace(/[-_]+/g, " ")
            .replace(/\s+/g, " ")
            .trim()
            .split(" ")
            .filter(part => part.length > 0)
            .map(part => part.charAt(0).toUpperCase() + part.slice(1))
            .join(" ");
    }

    function normalizedFollowMode(entry) {
        entry = entry || {};
        const favorite = String(entry.favoriteTeam || "").trim();
        return String(entry.followMode || "").trim() === "team" && favorite.length > 0 ? "team" : "league";
    }

    function scoreTextForPanel(match) {
        if (!matchHasDisplayScore(match))
            return "";

        const home = String(match && match.homeScore !== undefined ? match.homeScore : "").trim();
        const away = String(match && match.awayScore !== undefined ? match.awayScore : "").trim();
        return (home.length > 0 ? home : "0") + " - " + (away.length > 0 ? away : "0");
    }

    function liveMinuteText(value) {
        value = String(value || "").trim();
        if (value.length === 0)
            return "";

        return /^\d+\+?$/.test(value) ? value + "'" : value;
    }

    function panelTeamsScoreText(match) {
        match = match || {};
        const home = String(match.homeTeam || "").trim();
        const away = String(match.awayTeam || "").trim();
        const score = scoreTextForPanel(match);
        return home.length > 0 && away.length > 0 && score.length > 0 ? home + " " + score + " " + away : home.length > 0 && away.length > 0 ? home + " vs " + away : home + away;
    }

    function panelLiveText(match) {
        const minute = liveMinuteText(match && match.minute);
        return minute.length > 0 ? i18nc("@info:live match status", "Live %1", minute) : i18nc("@info:live match status", "Live");
    }

    function panelScheduleText(match) {
        const teams = panelTeamsScoreText(match);
        const status = String(match && (match.startTime || match.status) || "").trim();
        return status.length > 0 ? teams + " · " + status : teams;
    }

    function matchStatusText(match) {
        match = match || {};
        const minute = liveMinuteText(match.minute);
        if (minute.length > 0)
            return minute;

        const status = String(match.status || "").trim();
        if (SportsApi.isLiveMatch(match))
            return status.length > 0 ? status : i18nc("@info:live match status", "Live");

        return String(match.startTime || status || "").trim();
    }

    function matchHasDisplayScore(match) {
        match = match || {};
        if (SportsApi.isLiveMatch(match))
            return true;

        const status = String(match.status || "").trim().toLowerCase();
        if (status.indexOf("upcoming") >= 0 || status.indexOf("scheduled") >= 0 || status.indexOf("not started") >= 0 || status.indexOf("postponed") >= 0 || status.indexOf("cancel") >= 0)
            return false;

        const timestamp = Number(match.timestamp || 0);
        if (timestamp > Date.now())
            return false;

        const home = String(match.homeScore !== undefined ? match.homeScore : "").trim();
        const away = String(match.awayScore !== undefined ? match.awayScore : "").trim();
        if (home.length === 0 && away.length === 0)
            return false;

        return SportsApi.isFinishedMatch(match);
    }

    function matchForModel(match) {
        const copy = Object.assign({}, match || {});
        copy.showScore = matchHasDisplayScore(copy);
        return copy;
    }

    function emptySchedulesText() {
        return root.followTeamMode ? i18nc("@info:status", "No scheduled matches for %1.", root.favoriteTeam) : i18nc("@info:status", "No scheduled matches for the selected league.");
    }

    function setActiveSavedLeagueIndex(index) {
        const count = root.savedLeagueEntries.length;
        if (count === 0)
            return;

        const nextIndex = ((index % count) + count) % count;
        if (nextIndex === root.activeSavedLeagueIndex)
            return;

        Plasmoid.configuration.activeSavedLeagueIndex = nextIndex;
    }

    function isCurrentRefresh(token) {
        return token === root.refreshToken;
    }

    function isCurrentLiveRefresh(token) {
        return token === root.liveRefreshToken;
    }

    function openSportSettings() {
        const action = Plasmoid.internalAction("configure") || Plasmoid.action("configure");
        if (action)
            action.trigger();
    }

    function migrateDefaultSelection() {
        if (Plasmoid.configuration.defaultSelectionMigrated)
            return;

        const sports = String(Plasmoid.configuration.selectedSports || "").trim();
        const country = String(Plasmoid.configuration.country || "").trim();
        const league = String(Plasmoid.configuration.league || "").trim();
        const favorite = String(Plasmoid.configuration.favoriteTeam || "").trim();
        const saved = String(Plasmoid.configuration.savedLeagues || "[]").trim();
        if (sports === "football" && country === "england" && league === "english-premier-league" && favorite.length === 0 && (saved.length === 0 || saved === "[]")) {
            Plasmoid.configuration.selectedSports = "";
            Plasmoid.configuration.country = "";
            Plasmoid.configuration.league = "";
        }
        Plasmoid.configuration.defaultSelectionMigrated = true;
    }

    function refreshScores(manual) {
        if (!root.hasSportSelection()) {
            root.refreshToken += 1;
            root.liveRefreshToken += 1;
            refreshTimer.stop();
            liveRefreshTimer.stop();
            configRefreshTimer.stop();
            emptySchedulesTimer.stop();
            tableFallbackTimer.stop();
            liveMatchesModel.clear();
            scoresModel.clear();
            tableModel.clear();
            recentResultsListModel.clear();
            root.tableRows = [];
            root.primaryTableRows = [];
            root.latestLiveMatches = [];
            root.latestScheduleMatches = [];
            root.latestRecentMatches = [];
            root.discoveredTeamCompetitions = [];
            root.teamTableOptions = [];
            root.selectedTeamTableSlug = "";
            root.teamTableLoading = false;
            root.loading = false;
            root.liveLoading = false;
            root.schedulesLoading = false;
            root.recentResultsLoading = false;
            root.liveRefreshInFlight = false;
            root.pendingRequests = 0;
            root.tableRequestCompleted = true;
            root.scheduleRequestCompleted = true;
            root.tableScheduleFallbackStarted = false;
            root.recentResultsTableFallbackStarted = false;
            root.errorMessage = i18nc("@info:status", "Add a sport in the widget settings.");
            root.tableErrorMessage = "";
            root.lastUpdatedText = "";
            return;
        }

        if (!refreshTimer.running)
            refreshTimer.start();

        if (Plasmoid.configuration.liveRefreshEnabled && !liveRefreshTimer.running)
            liveRefreshTimer.start();

        const token = root.refreshToken + 1;
        root.refreshToken = token;
        root.liveRefreshToken += 1;
        root.liveRefreshInFlight = false;
        const options = {
            "provider": effectiveProvider(),
            "baseUrl": effectiveBaseUrl(),
            "apiKey": String(Plasmoid.configuration.apiKey || "").trim(),
            "sports": root.selectedSport,
            "country": root.selectedCountry,
            "league": root.selectedLeague,
            "favoriteTeam": root.favoriteTeam,
            "followMode": root.followMode,
            "refreshToken": token,
            "forceLiveRefresh": Boolean(manual),
            "scoreboardDaysBack": 30,
            "scoreboardDaysForward": 90
        };
        root.pendingRequests = 4;
        root.refreshErrors = [];
        root.tableRequestCompleted = false;
        root.scheduleRequestCompleted = false;
        root.tableScheduleFallbackStarted = false;
        root.recentResultsTableFallbackStarted = false;
        root.currentManualRefresh = manual;
        root.loading = true;
        root.liveLoading = true;
        root.schedulesLoading = true;
        root.recentResultsLoading = true;
        root.pendingScheduleMessage = "";
        root.primaryTableRows = [];
        root.latestLiveMatches = [];
        root.latestScheduleMatches = [];
        root.latestRecentMatches = [];
        root.discoveredTeamCompetitions = [];
        root.teamTableLoading = false;
        root.teamTableRequestToken += 1;
        emptySchedulesTimer.stop();
        root.errorMessage = "";
        syncTeamTableOptions();
        applyTable([], true);
        root.tableErrorMessage = "";
        recentResultsListModel.clear();
        tableFallbackTimer.restart();
        SportsApi.fetchLiveScores(options, (matches) => {
            if (!root.isCurrentRefresh(token))
                return;

            applyLiveMatches(matches);
            root.liveLoading = false;
            finishRefresh(manual, "", token);
        }, (message) => {
            if (!root.isCurrentRefresh(token))
                return;

            applyLiveMatches([]);
            root.liveLoading = false;
            finishRefresh(manual, message, token);
        });
        SportsApi.fetchLeagueTable(options, (table) => {
            if (!root.isCurrentRefresh(token))
                return;

            const alreadyCounted = root.tableRequestCompleted;
            table = Array.isArray(table) ? table : [];
            root.tableRequestCompleted = true;
            tableFallbackTimer.stop();
            if (table.length > 0) {
                applyTable(table, true);
                root.tableErrorMessage = "";
                refreshTeamCompetitionOptions(options);
                enrichTableForm(Object.assign({}, options, {
                    "followMode": "league",
                    "league": root.currentDisplayTableSlug()
                }));
                refreshRecentResultsFromTable(options);
                if (root.followTeamMode || (root.scheduleRequestCompleted && scoresModel.count === 0))
                    refreshSchedulesFromTable(options);
            } else {
                applyTable([], true);
                root.tableErrorMessage = i18nc("@info:status", "No table rows returned for %1.", root.selectedLeagueLabel || root.selectedLeague);
                if (root.followTeamMode)
                    refreshClubModeSections(options);
            }

            if (!alreadyCounted)
                finishRefresh(manual, "", token);
        }, (message) => {
            if (!root.isCurrentRefresh(token))
                return;

            const alreadyCounted = root.tableRequestCompleted;
            root.tableRequestCompleted = true;
            tableFallbackTimer.stop();
            applyTable([], true);
            root.tableErrorMessage = message;
            if (root.followTeamMode)
                refreshClubModeSections(options);
            if (!alreadyCounted)
                finishRefresh(manual, message, token);
        });
        SportsApi.fetchScoresFixtures(options, (fixtures) => {
            if (!root.isCurrentRefresh(token))
                return;

            root.scheduleRequestCompleted = true;
            if (root.followTeamMode) {
                if (root.rowsForFollowMode().length > 0) {
                    refreshSchedulesFromTable(options);
                } else if (root.tableRequestCompleted && root.rowsForFollowMode().length === 0) {
                    deferEmptySchedulesMessage("");
                }
                finishRefresh(manual, "", token);
                return;
            }

            const scheduledCount = applySchedules(fixtures, i18nc("@info:status", "Updated %1", Qt.formatTime(new Date(), "hh:mm")));
            if (scheduledCount > 0) {
                emptySchedulesTimer.stop();
                root.schedulesLoading = false;
            } else if (root.tableRows.length > 0) {
                refreshSchedulesFromTable(options);
            } else if (root.tableRequestCompleted && root.tableRows.length === 0) {
                deferEmptySchedulesMessage("");
            }

            finishRefresh(manual, "", token);
        }, (message) => {
            if (!root.isCurrentRefresh(token))
                return;

            root.scheduleRequestCompleted = true;
            if (root.followTeamMode) {
                if (root.rowsForFollowMode().length > 0) {
                    refreshSchedulesFromTable(options);
                } else if (root.tableRequestCompleted && root.rowsForFollowMode().length === 0) {
                    deferEmptySchedulesMessage(message);
                }
                finishRefresh(manual, message, token);
                return;
            }

            applySchedules([], i18nc("@info:status", "Updated %1", Qt.formatTime(new Date(), "hh:mm")));
            if (root.tableRows.length > 0) {
                refreshSchedulesFromTable(options);
            } else if (root.tableRequestCompleted && root.tableRows.length === 0) {
                deferEmptySchedulesMessage(message);
            }

            finishRefresh(manual, message, token);
        });
        SportsApi.fetchRecentResults(options, (results) => {
            if (!root.isCurrentRefresh(token))
                return;

            if (root.followTeamMode && root.recentResultsTableFallbackStarted) {
                finishRefresh(manual, "", token);
                return;
            }

            const hasResults = results.length > 0;
            if (!root.followTeamMode && (results.length > 0 || recentResultsListModel.count === 0))
                applyRecentResults(results);
            if (hasResults || !root.recentResultsTableFallbackStarted)
                root.recentResultsLoading = false;
            finishRefresh(manual, "", token);
        }, (message) => {
            if (!root.isCurrentRefresh(token))
                return;

            if (!root.followTeamMode && recentResultsListModel.count === 0)
                applyRecentResults([]);
            if (!root.recentResultsTableFallbackStarted)
                root.recentResultsLoading = false;
            finishRefresh(manual, message, token);
        });
    }

    function refreshLiveMatches(manual) {
        if (!root.hasSportSelection())
            return;

        if (!Plasmoid.configuration.liveRefreshEnabled && !manual)
            return;

        if (root.liveRefreshInFlight && !manual)
            return;

        const token = root.liveRefreshToken + 1;
        root.liveRefreshToken = token;
        const selectedSport = root.selectedSport;
        const selectedCountry = root.selectedCountry;
        const selectedLeague = root.selectedLeague;
        const selectedFollowMode = root.followMode;
        const options = {
            "provider": effectiveProvider(),
            "baseUrl": effectiveBaseUrl(),
            "apiKey": String(Plasmoid.configuration.apiKey || "").trim(),
            "sports": selectedSport,
            "country": selectedCountry,
            "league": selectedLeague,
            "favoriteTeam": root.favoriteTeam,
            "followMode": root.followMode,
            "refreshToken": root.refreshToken,
            "forceLiveRefresh": true,
            "scoreboardDaysBack": 1,
            "scoreboardDaysForward": 1
        };

        root.liveLoading = liveMatchesModel.count === 0;
        root.liveRefreshInFlight = true;
        SportsApi.fetchLiveScores(options, (matches) => {
            if (!root.isCurrentLiveRefresh(token))
                return;

            if (selectedSport !== root.selectedSport || selectedCountry !== root.selectedCountry || selectedLeague !== root.selectedLeague || selectedFollowMode !== root.followMode) {
                root.liveRefreshInFlight = false;
                return;
            }

            applyLiveMatches(matches);
            root.liveLoading = false;
            root.liveRefreshInFlight = false;
            root.lastUpdatedText = i18nc("@info:status", "Updated %1", Qt.formatTime(new Date(), "hh:mm"));
        }, () => {
            if (!root.isCurrentLiveRefresh(token))
                return;

            root.liveLoading = false;
            root.liveRefreshInFlight = false;
        });
    }

    function refreshSchedulesFromTable(options) {
        if (!root.isCurrentRefresh(options.refreshToken))
            return;

        if (root.tableScheduleFallbackStarted)
            return;

        const rows = root.rowsForFollowMode();
        if (rows.length === 0) {
            deferEmptySchedulesMessage("");

            return;
        }

        root.tableScheduleFallbackStarted = true;
        root.schedulesLoading = true;
        emptySchedulesTimer.stop();

        SportsApi.fetchScoresFixtures(Object.assign({}, root.matchScopeOptions(options), {
            "tableRows": rows
        }), (fixtures) => {
            if (!root.isCurrentRefresh(options.refreshToken))
                return;

            const scheduledCount = applySchedules(fixtures, i18nc("@info:status", "Updated %1", Qt.formatTime(new Date(), "hh:mm")));
            if (scheduledCount > 0) {
                emptySchedulesTimer.stop();
                root.schedulesLoading = false;
            } else {
                deferEmptySchedulesMessage("");
            }

        }, (message) => {
            if (!root.isCurrentRefresh(options.refreshToken))
                return;

            deferEmptySchedulesMessage(message);
        });
    }

    function refreshRecentResultsFromTable(options) {
        if (!root.isCurrentRefresh(options.refreshToken))
            return;

        if (root.recentResultsTableFallbackStarted)
            return;

        const rows = root.rowsForFollowMode();
        if (rows.length === 0) {
            root.recentResultsLoading = false;
            return;
        }

        root.recentResultsTableFallbackStarted = true;
        root.recentResultsLoading = recentResultsListModel.count === 0;

        SportsApi.fetchRecentResults(Object.assign({}, root.matchScopeOptions(options), {
            "tableRows": rows,
            "preferTeamRecentResults": true
        }), (results) => {
            if (!root.isCurrentRefresh(options.refreshToken))
                return;

            if ((results.length > 0 && (recentResultsListModel.count === 0 || results.length > recentResultsListModel.count)) || recentResultsListModel.count === 0)
                applyRecentResults(results);
            root.recentResultsLoading = false;
        }, (message) => {
            if (!root.isCurrentRefresh(options.refreshToken))
                return;

            root.recentResultsLoading = false;
        });
    }

    function rowsForFollowMode() {
        if (!root.followTeamMode)
            return root.tableRows;

        const rows = root.primaryTableRows.filter((row) => isFavoriteMatch(row)).slice(0, 1);
        if (rows.length > 0)
            return rows;

        if (root.favoriteTeam.length === 0)
            return [];

        return [{
            "team": root.favoriteTeam,
            "teamSlug": ProviderCatalog.sportScoreSlug(root.favoriteTeam)
        }];
    }

    function refreshClubModeSections(options) {
        if (!root.followTeamMode)
            return;

        refreshTeamCompetitionOptions(options);
        refreshRecentResultsFromTable(options);
        refreshSchedulesFromTable(options);
    }

    function enrichTableForm(options) {
        const requestSport = SportVisuals.normalizedSport(options.sports);
        const requestLeague = ProviderCatalog.sportScoreSlug(options.league);
        SportsApi.fetchLeagueForm(Object.assign({}, options, {
            "provider": "sportscore",
            "baseUrl": "https://sportscore.com/api/widget",
            "tableRows": root.tableRows
        }), (formByTeam) => {
            if (!root.isCurrentRefresh(options.refreshToken))
                return;

            if (requestSport !== SportVisuals.normalizedSport(root.selectedSport) || requestLeague !== root.currentDisplayTableSlug())
                return;

            if (Object.keys(formByTeam).length === 0)
                return;

            const rows = root.tableRows.map((row) => {
                const form = SportsApi.formForTeam(formByTeam, row.team);
                if (!form || form.length === 0)
                    return row;

                const copy = Object.assign({}, row);
                copy.form = form;
                copy.formDetails = SportsApi.formDetailsForTeam(formByTeam, row.team);
                return copy;
            });
            applyTable(rows, !root.followTeamMode || root.currentDisplayTableSlug() === ProviderCatalog.sportScoreSlug(root.selectedLeague));
        }, () => {
        });
    }

    function currentDisplayTableSlug() {
        if (!root.followTeamMode)
            return ProviderCatalog.sportScoreSlug(root.selectedLeague);

        const selected = ProviderCatalog.sportScoreSlug(root.selectedTeamTableSlug);
        return selected.length > 0 ? selected : ProviderCatalog.sportScoreSlug(root.selectedLeague);
    }

    function currentDisplayTableLabel() {
        const slug = root.currentDisplayTableSlug();
        for (let index = 0; index < root.teamTableOptions.length; index += 1) {
            const option = root.teamTableOptions[index];
            if (ProviderCatalog.sportScoreSlug(option.slug) === slug)
                return String(option.label || "").trim();
        }

        const label = ProviderCatalog.leagueLabel(slug);
        if (label.length > 0)
            return label;

        return root.followTeamMode ? root.titleFromSlug(slug) : root.selectedLeagueLabel;
    }

    function addTeamTableOption(options, seen, label, slug) {
        const normalizedSlug = ProviderCatalog.sportScoreSlug(slug || label);
        if (normalizedSlug.length === 0 || seen[normalizedSlug])
            return;

        const normalizedLabel = String(label || ProviderCatalog.leagueLabel(normalizedSlug) || root.titleFromSlug(normalizedSlug)).trim();
        seen[normalizedSlug] = true;
        options.push({
            "slug": normalizedSlug,
            "label": normalizedLabel
        });
    }

    function addTeamTableOptionsFromMatches(options, seen, matches) {
        (Array.isArray(matches) ? matches : []).forEach(match => {
            const label = String(match && match.league || "").trim();
            if (label.length === 0)
                return;

            root.addTeamTableOption(options, seen, label, label);
        });
    }

    function addTeamTableOptionsFromCompetitions(options, seen, competitions) {
        (Array.isArray(competitions) ? competitions : []).forEach(competition => {
            const label = String(competition && competition.label || "").trim();
            const slug = String(competition && competition.slug || label).trim();
            root.addTeamTableOption(options, seen, label, slug);
        });
    }

    function collectTeamTableOptions() {
        if (!root.followTeamMode)
            return [];

        let seen = {};
        let options = [];
        root.addTeamTableOption(options, seen, root.selectedLeagueLabel, root.selectedLeague);
        root.addTeamTableOptionsFromCompetitions(options, seen, root.discoveredTeamCompetitions);
        root.addTeamTableOptionsFromMatches(options, seen, root.filterFavoriteMatches(root.latestLiveMatches));
        root.addTeamTableOptionsFromMatches(options, seen, root.filterFavoriteMatches(root.latestScheduleMatches));
        root.addTeamTableOptionsFromMatches(options, seen, root.filterFavoriteMatches(root.latestRecentMatches));
        return options;
    }

    function refreshTeamCompetitionOptions(options) {
        if (!root.followTeamMode || root.favoriteTeam.length === 0)
            return;

        const requestToken = options.refreshToken;
        SportsApi.fetchTeamCompetitions(Object.assign({}, options, {
            "tableRows": root.rowsForFollowMode()
        }), (competitions) => {
            if (!root.isCurrentRefresh(requestToken))
                return;

            root.discoveredTeamCompetitions = Array.isArray(competitions) ? competitions : [];
            syncTeamTableOptions();
        }, () => {
        });
    }

    function syncTeamTableOptions() {
        const options = root.collectTeamTableOptions();
        root.teamTableOptions = options;
        if (!root.followTeamMode) {
            root.selectedTeamTableSlug = "";
            return;
        }

        const fallbackSlug = ProviderCatalog.sportScoreSlug(root.selectedLeague);
        const currentSlug = ProviderCatalog.sportScoreSlug(root.selectedTeamTableSlug);
        const hasCurrent = options.some(option => ProviderCatalog.sportScoreSlug(option.slug) === currentSlug);
        if (currentSlug.length === 0 || !hasCurrent)
            root.selectedTeamTableSlug = fallbackSlug;
    }

    function selectTeamTable(slug) {
        if (!root.followTeamMode)
            return;

        const normalizedSlug = ProviderCatalog.sportScoreSlug(slug);
        if (normalizedSlug.length === 0 || normalizedSlug === root.currentDisplayTableSlug())
            return;

        root.selectedTeamTableSlug = normalizedSlug;
        root.refreshDisplayTableForSelection();
        root.refreshScopedTeamMatches();
    }

    function refreshScopedTeamMatches() {
        if (!root.followTeamMode || !root.hasSportSelection())
            return;

        root.tableScheduleFallbackStarted = false;
        root.recentResultsTableFallbackStarted = false;
        const options = root.currentRequestOptions();
        if (root.rowsForFollowMode().length > 0) {
            refreshSchedulesFromTable(options);
            refreshRecentResultsFromTable(options);
        } else {
            applySchedules(root.latestScheduleMatches, root.lastUpdatedText);
            applyRecentResults(root.latestRecentMatches);
        }
    }

    function currentRequestOptions() {
        return {
            "provider": effectiveProvider(),
            "baseUrl": effectiveBaseUrl(),
            "apiKey": String(Plasmoid.configuration.apiKey || "").trim(),
            "sports": root.selectedSport,
            "country": root.selectedCountry,
            "league": root.selectedLeague,
            "favoriteTeam": root.favoriteTeam,
            "followMode": root.followMode,
            "refreshToken": root.refreshToken,
            "scoreboardDaysBack": 30,
            "scoreboardDaysForward": 90
        };
    }

    function matchScopeOptions(options) {
        if (!root.followTeamMode)
            return options;

        const scope = root.currentDisplayTableSlug();
        if (scope.length === 0)
            return options;

        const scoped = Object.assign({}, options);
        scoped.league = scope;
        scoped.followMode = "league";
        return scoped;
    }

    function refreshDisplayTableForSelection() {
        if (!root.followTeamMode)
            return;

        const slug = root.currentDisplayTableSlug();
        const primarySlug = ProviderCatalog.sportScoreSlug(root.selectedLeague);
        root.teamTableRequestToken += 1;
        const token = root.teamTableRequestToken;
        if (slug.length === 0 || slug === primarySlug) {
            root.teamTableLoading = false;
            applyTable(root.primaryTableRows, false);
            root.tableErrorMessage = root.primaryTableRows.length > 0 ? "" : i18nc("@info:status", "No table rows returned for %1.", root.selectedLeagueLabel || root.selectedLeague);
            enrichTableForm({
                "provider": effectiveProvider(),
                "baseUrl": effectiveBaseUrl(),
                "apiKey": String(Plasmoid.configuration.apiKey || "").trim(),
                "sports": root.selectedSport,
                "country": root.selectedCountry,
                "league": slug,
                "followMode": "league",
                "refreshToken": root.refreshToken
            });
            return;
        }

        root.teamTableLoading = true;
        root.tableErrorMessage = "";
        SportsApi.fetchLeagueTable({
            "provider": effectiveProvider(),
            "baseUrl": effectiveBaseUrl(),
            "apiKey": String(Plasmoid.configuration.apiKey || "").trim(),
            "sports": root.selectedSport,
            "country": root.selectedCountry,
            "league": slug,
            "followMode": "league",
            "refreshToken": root.refreshToken
        }, (table) => {
            if (token !== root.teamTableRequestToken)
                return;

            root.teamTableLoading = false;
            table = Array.isArray(table) ? table : [];
            applyTable(table, false);
            root.tableErrorMessage = table.length > 0 ? "" : i18nc("@info:status", "No table rows returned for %1.", root.currentDisplayTableLabel());
            if (table.length > 0) {
                enrichTableForm({
                    "provider": effectiveProvider(),
                    "baseUrl": effectiveBaseUrl(),
                    "apiKey": String(Plasmoid.configuration.apiKey || "").trim(),
                    "sports": root.selectedSport,
                    "country": root.selectedCountry,
                    "league": slug,
                    "followMode": "league",
                    "refreshToken": root.refreshToken
                });
            }
        }, (message) => {
            if (token !== root.teamTableRequestToken)
                return;

            root.teamTableLoading = false;
            applyTable([], false);
            root.tableErrorMessage = message;
        });
    }

    function finishRefresh(manual, message, token) {
        if (!root.isCurrentRefresh(token))
            return;

        if (message && message.length > 0)
            root.refreshErrors = root.refreshErrors.concat([message]);

        root.pendingRequests -= 1;
        if (root.pendingRequests > 0)
            return ;

        promoteLiveMatches(root.latestScheduleMatches);
        root.loading = false;
        if (root.refreshErrors.length > 0 && liveMatchesModel.count === 0 && scoresModel.count === 0 && recentResultsListModel.count === 0 && tableModel.count === 0) {
            emptySchedulesTimer.stop();
            root.schedulesLoading = false;
            root.errorMessage = manual ? root.refreshErrors.join(", ") : "";
        } else {
            if (root.schedulesLoading && root.tableRequestCompleted && root.tableRows.length === 0)
                deferEmptySchedulesMessage("");

            if (!root.schedulesLoading && scoresModel.count === 0 && root.errorMessage.length === 0)
                deferEmptySchedulesMessage("");

            if (manual && root.refreshErrors.length > 0)
                root.errorMessage = root.refreshErrors.join(", ");
        }
    }

    function applySchedules(matches, updateText) {
        scoresModel.clear();
        root.latestScheduleMatches = Array.isArray(matches) ? matches.slice() : [];
        promoteLiveMatches(root.latestScheduleMatches);
        syncTeamTableOptions();
        matches = scheduledMatches(root.latestScheduleMatches);
        matches = filterFavoriteMatches(matches);
        matches = filterCurrentCompetitionMatches(matches);
        matches = prioritizeFavorite(matches);
        if (Plasmoid.configuration.prioritizePopular) {
            matches = matches.slice().sort((left, right) => {
                return Number(Boolean(right.popular)) - Number(Boolean(left.popular));
            });
            matches = prioritizeFavorite(matches);
        }
        matches.forEach((match) => {
            return scoresModel.append(matchForModel(match));
        });
        if (matches.length > 0) {
            root.errorMessage = "";
        } else if (!root.schedulesLoading) {
            root.errorMessage = emptySchedulesText();
        }

        root.lastUpdatedText = updateText;
        return matches.length;
    }

    function applyLiveMatches(matches) {
        liveMatchesModel.clear();
        const sourceMatches = Array.isArray(matches) ? matches.slice() : [];
        root.latestLiveMatches = sourceMatches;
        syncTeamTableOptions();
        matches = filterFavoriteMatches(sourceMatches);
        matches = filterCurrentCompetitionMatches(matches);
        matches = prioritizeFavorite(matches);
        matches.forEach((match) => {
            return liveMatchesModel.append(matchForModel(match));
        });
        return matches.length;
    }

    function applyRecentResults(matches) {
        recentResultsListModel.clear();
        const sourceMatches = Array.isArray(matches) ? matches.slice() : [];
        root.latestRecentMatches = sourceMatches;
        syncTeamTableOptions();
        matches = filterFavoriteMatches(sourceMatches);
        matches = filterCurrentCompetitionMatches(matches);
        matches = sortRecentResultsByDate(matches);
        matches.forEach((match) => {
            return recentResultsListModel.append(matchForModel(match));
        });
        return matches.length;
    }

    function sortRecentResultsByDate(matches) {
        return (Array.isArray(matches) ? matches.slice() : []).sort((left, right) => {
            const leftTime = Number(left && left.timestamp || 0);
            const rightTime = Number(right && right.timestamp || 0);
            if (leftTime > 0 && rightTime > 0 && leftTime !== rightTime)
                return rightTime - leftTime;

            if (leftTime > 0 && rightTime === 0)
                return -1;

            if (rightTime > 0 && leftTime === 0)
                return 1;

            const leftStart = String(left && left.startTime || "");
            const rightStart = String(right && right.startTime || "");
            if (leftStart !== rightStart)
                return rightStart.localeCompare(leftStart);

            return String(left && left.homeTeam || "").localeCompare(String(right && right.homeTeam || ""));
        });
    }

    function promoteLiveMatches(matches) {
        if (liveMatchesModel.count > 0)
            return 0;

        const liveMatches = (Array.isArray(matches) ? matches : []).filter((match) => {
            return SportsApi.isLiveMatch(match);
        }).map((match) => liveMatchForModel(match));
        if (liveMatches.length === 0)
            return 0;

        return applyLiveMatches(liveMatches);
    }

    function liveMatchForModel(match) {
        const copy = Object.assign({}, match);
        const status = String(copy.status || "").trim();
        const lowerStatus = status.toLowerCase();
        if (String(copy.minute || "").length === 0 && (lowerStatus === "ht" || lowerStatus === "1h" || lowerStatus === "2h" || /^\d+\+?$/.test(status)))
            copy.minute = status;

        copy.status = "Live";
        return copy;
    }

    function deferEmptySchedulesMessage(message) {
        if (scoresModel.count > 0)
            return;

        root.pendingScheduleMessage = message && message.length > 0 ? message : emptySchedulesText();
        root.schedulesLoading = true;
        root.errorMessage = "";
        emptySchedulesTimer.restart();
    }

    function scheduledMatches(matches) {
        const now = Date.now();
        return (Array.isArray(matches) ? matches : []).filter((match) => {
            const status = String(match.status || "").toLowerCase();
            const timestamp = Number(match.timestamp || 0);
            if (SportsApi.isLiveMatch(match))
                return false;

            if (status.indexOf("finished") >= 0 || status.indexOf("final") >= 0)
                return false;

            if (status.indexOf("upcoming") >= 0 || status.indexOf("scheduled") >= 0 || status.indexOf("not started") >= 0 || status.indexOf("postponed") >= 0)
                return timestamp === 0 || timestamp >= now - 3 * 60 * 60 * 1000;

            if (timestamp > 0)
                return timestamp >= now - 3 * 60 * 60 * 1000;

            return String(match.homeScore || "").length === 0 && String(match.awayScore || "").length === 0;
        }).sort((left, right) => {
            const leftTime = Number(left.timestamp || 0);
            const rightTime = Number(right.timestamp || 0);
            if (leftTime > 0 && rightTime > 0 && leftTime !== rightTime)
                return leftTime - rightTime;

            if (leftTime > 0 && rightTime === 0)
                return -1;

            if (rightTime > 0 && leftTime === 0)
                return 1;

            return String(left.homeTeam || "").localeCompare(String(right.homeTeam || ""));
        });
    }

    function applyTable(rows, updatePrimary) {
        rows = Array.isArray(rows) ? rows : [];
        if (updatePrimary !== false)
            root.primaryTableRows = rows.slice();

        root.tableRows = rows.slice();
        tableModel.clear();
        rows.forEach((row) => {
            return tableModel.append(row);
        });
    }

    function prioritizeFavorite(items) {
        if (root.favoriteTeam.length === 0)
            return items;

        return items.slice().sort((left, right) => {
            return Number(isFavoriteMatch(right)) - Number(isFavoriteMatch(left));
        });
    }

    function filterFavoriteMatches(items) {
        if (!root.followTeamMode || root.favoriteTeam.length === 0)
            return items;

        return items.filter((match) => isFavoriteMatch(match));
    }

    function filterCurrentCompetitionMatches(items) {
        if (!root.followTeamMode)
            return items;

        const scope = root.currentDisplayTableSlug();
        if (scope.length === 0)
            return items;

        return items.filter((match) => {
            const matchLeague = ProviderCatalog.sportScoreSlug(match && match.league);
            return matchLeague.length > 0 && matchLeague === scope;
        });
    }

    function isFavoriteMatch(match) {
        const favorite = root.favoriteTeam.toLowerCase();
        if (favorite.length === 0)
            return false;

        return root.isFavoriteTeamName(match.homeTeam) || root.isFavoriteTeamName(match.awayTeam) || root.isFavoriteTeamName(match.team);
    }

    function isFavoriteTeamName(teamName) {
        const favorite = root.favoriteTeam;
        if (favorite.length === 0)
            return false;

        return SportsApi.sameTeamName(teamName, favorite) || String(teamName || "").toLowerCase().indexOf(favorite.toLowerCase()) >= 0;
    }

    function providerDisplayName(provider) {
        return ProviderCatalog.displayName("sportscore");
    }

    function effectiveProvider() {
        return "sportscore";
    }

    function effectiveBaseUrl() {
        const provider = effectiveProvider();
        const configured = String(Plasmoid.configuration.apiBaseUrl || "").trim();
        const defaultUrl = providerDefaultBaseUrl(provider);
        if (configured.length === 0 || (isKnownProviderUrl(configured) && configured.indexOf(defaultUrl) < 0))
            return defaultUrl;

        return configured;
    }

    function providerDefaultBaseUrl(provider) {
        return ProviderCatalog.defaultBaseUrl("sportscore");
    }

    function isKnownProviderUrl(url) {
        const known = ["sportscore.com"];
        for (let index = 0; index < known.length; index += 1) {
            if (url.indexOf(known[index]) >= 0)
                return true;

        }
        return false;
    }

    function scheduleConfigRefresh() {
        configRefreshTimer.restart();
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground
    Plasmoid.icon: "applications-games"
    Plasmoid.title: i18n("Sports Widget for Plasma")
    Layout.fillWidth: Plasmoid.formFactor === PlasmaCore.Types.Horizontal && root.panelAreaFill
    Layout.fillHeight: Plasmoid.formFactor === PlasmaCore.Types.Vertical && root.panelAreaFill
    Layout.minimumWidth: Plasmoid.formFactor === PlasmaCore.Types.Horizontal ? root.panelAreaFill ? 0 : root.compactPanelWidth : -1
    Layout.preferredWidth: Plasmoid.formFactor === PlasmaCore.Types.Horizontal ? root.panelAreaFill ? -1 : root.compactPanelWidth : -1
    Layout.minimumHeight: Plasmoid.formFactor === PlasmaCore.Types.Vertical && root.panelAreaMode === "manual" ? root.panelAreaSize : -1
    Layout.preferredHeight: Plasmoid.formFactor === PlasmaCore.Types.Vertical ? root.panelAreaFill ? -1 : root.panelAreaMode === "manual" ? root.panelAreaSize : -1 : -1
    toolTipMainText: Plasmoid.title
    toolTipSubText: !root.hasSportSelection() ? i18nc("@info:tooltip", "Add a sport") : liveCount > 0 ? i18ncp("@info:tooltip", "%1 live match", "%1 live matches", liveCount) : scheduleCount > 0 ? i18ncp("@info:tooltip", "%1 scheduled match", "%1 scheduled matches", scheduleCount) : i18nc("@info:tooltip", "No scheduled matches")
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation
    Component.onCompleted: {
        migrateDefaultSelection();
        refreshScores(false);
    }
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nc("@action", "Refresh")
            icon.name: "view-refresh"
            enabled: root.hasSportSelection()
            onTriggered: root.refreshScores(true)
        }
    ]

    ListModel {
        id: liveMatchesModel
    }

    ListModel {
        id: scoresModel
    }

    ListModel {
        id: tableModel
    }

    ListModel {
        id: recentResultsListModel
    }

    Timer {
        id: refreshTimer

        interval: Math.max(1, Plasmoid.configuration.refreshInterval) * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refreshScores(false)
    }

    Timer {
        id: liveRefreshTimer

        interval: Math.max(10, Number(Plasmoid.configuration.liveRefreshInterval || 30)) * 1000
        repeat: true
        running: false
        onTriggered: root.refreshLiveMatches(false)
    }

    Timer {
        id: tableFallbackTimer

        interval: 15000
        repeat: false
        onTriggered: {
            if (root.tableRequestCompleted)
                return ;

            root.tableRequestCompleted = true;
            applyTable([]);
            root.tableErrorMessage = i18nc("@info:status", "Table request timed out.");
            finishRefresh(root.currentManualRefresh, i18nc("@info:status", "Table request timed out."), root.refreshToken);
        }
    }

    Timer {
        id: configRefreshTimer

        interval: 60
        repeat: false
        onTriggered: root.refreshScores(true)
    }

    Timer {
        id: emptySchedulesTimer

        interval: 2500
        repeat: false
        onTriggered: {
            root.schedulesLoading = false;
            if (scoresModel.count === 0)
                root.errorMessage = root.pendingScheduleMessage.length > 0 ? root.pendingScheduleMessage : emptySchedulesText();

            root.pendingScheduleMessage = "";
        }
    }

    Connections {
        target: Plasmoid.configuration
        ignoreUnknownSignals: true

        function onApiBaseUrlChanged() {
            root.scheduleConfigRefresh();
        }

        function onApiKeyChanged() {
            root.scheduleConfigRefresh();
        }

        function onFavoriteTeamChanged() {
            root.scheduleConfigRefresh();
        }

        function onCountryChanged() {
            root.scheduleConfigRefresh();
        }

        function onLeagueChanged() {
            root.scheduleConfigRefresh();
        }

        function onPrioritizePopularChanged() {
            root.scheduleConfigRefresh();
        }

        function onProviderChanged() {
            root.scheduleConfigRefresh();
        }

        function onRefreshIntervalChanged() {
            root.scheduleConfigRefresh();
        }

        function onLiveRefreshEnabledChanged() {
            if (Plasmoid.configuration.liveRefreshEnabled && root.hasSportSelection()) {
                liveRefreshTimer.restart();
                root.refreshLiveMatches(true);
            } else {
                liveRefreshTimer.stop();
            }
        }

        function onLiveRefreshIntervalChanged() {
            if (liveRefreshTimer.running)
                liveRefreshTimer.restart();
        }

        function onSelectedSportsChanged() {
            root.scheduleConfigRefresh();
        }

        function onSavedLeaguesChanged() {
            root.scheduleConfigRefresh();
        }

        function onActiveSavedLeagueIndexChanged() {
            root.scheduleConfigRefresh();
        }

    }

    compactRepresentation: CompactRepresentation {
        liveCount: root.liveCount
        loading: root.loading || root.schedulesLoading
        layoutMode: Plasmoid.configuration.panelLayoutMode
        primaryText: root.primaryMatchText
        secondaryText: root.secondaryMatchText
        panelText: root.panelHeroText
        liveText: root.panelHeroLiveText
        isLive: root.panelHeroLive
        homeTeam: root.panelHeroHomeTeam
        awayTeam: root.panelHeroAwayTeam
        homeScore: root.panelHeroHomeScore
        awayScore: root.panelHeroAwayScore
        showScore: root.panelHeroShowScore
        statusText: root.panelHeroStatusText
        stadium: root.panelHeroStadium
        homeBadge: root.panelHeroHomeBadge
        awayBadge: root.panelHeroAwayBadge
        favoriteTeam: root.followTeamMode ? root.favoriteTeam : ""
        panelUseSystemFont: Plasmoid.configuration.panelUseSystemFont
        panelFontFamily: Plasmoid.configuration.panelFontFamily
        panelFontSize: Plasmoid.configuration.panelFontSize
        panelFontBold: Plasmoid.configuration.panelFontBold
        panelEmblemSize: Plasmoid.configuration.panelEmblemSize
        panelAreaMode: root.panelAreaMode
        panelAreaSize: root.panelAreaSize
        sport: root.primarySport
    }

    fullRepresentation: FullRepresentation {
        liveModel: liveMatchesModel
        scoreModel: scoresModel
        recentResultsModel: recentResultsListModel
        loading: root.loading
        liveLoading: root.liveLoading
        schedulesLoading: root.schedulesLoading
        recentResultsLoading: root.recentResultsLoading
        errorMessage: root.errorMessage
        tableErrorMessage: root.tableErrorMessage
        lastUpdatedText: root.lastUpdatedText
        providerLabel: root.providerLabel
        sourceText: root.sourceText
        primaryText: root.primaryMatchText
        secondaryText: root.secondaryMatchText
        sportCount: 1
        sport: root.primarySport
        hasSavedLeagues: root.savedLeagueCount > 0
        savedLeagues: root.savedLeagueEntries
        savedLeagueCount: root.savedLeagueCount
        activeSavedLeagueIndex: root.activeSavedLeagueIndex
        activeLeagueLabel: root.activeDisplayLabel
        activeCountryLabel: root.activeDisplayCountryLabel
        activeClubBadge: root.activeClubBadge
        tableLeagueLabel: root.currentDisplayTableLabel()
        followTeamMode: root.followTeamMode
        teamTableOptions: root.teamTableOptions
        selectedTableSlug: root.currentDisplayTableSlug()
        tableLoading: root.teamTableLoading
        tableModel: tableModel
        tableRows: root.tableRows
        league: root.selectedLeague
        tableCount: root.tableCount
        recentResultsCount: root.recentResultsCount
        widgetTabs: Plasmoid.configuration.widgetTabs
        favoriteTeam: root.favoriteTeam
        onRefreshRequested: root.refreshScores(true)
        onConfigureRequested: root.openSportSettings()
        onLeagueSelected: (index) => root.setActiveSavedLeagueIndex(index)
        onTeamTableSelected: (slug) => root.selectTeamTable(slug)
    }

}
