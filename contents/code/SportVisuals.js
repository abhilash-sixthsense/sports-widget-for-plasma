/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

.pragma library

function normalizedSport(value) {
    const sport = String(value || "").toLowerCase();
    if (sport.length === 0)
        return "";
    if (sport.indexOf("american") >= 0 || sport === "nfl")
        return "american-football";
    if (sport.indexOf("basket") >= 0 || sport === "nba")
        return "basketball";
    if (sport.indexOf("base") >= 0 || sport === "mlb")
        return "baseball";
    if (sport.indexOf("cricket") >= 0)
        return "cricket";
    if (sport.indexOf("hockey") >= 0 || sport === "nhl")
        return "hockey";
    if (sport.indexOf("snooker") >= 0)
        return "snooker";
    if (sport.indexOf("tennis") >= 0)
        return "tennis";
    if (sport.indexOf("volley") >= 0)
        return "volleyball";
    return "football";
}

function iconName(value) {
    const sport = normalizedSport(value);
    return (sport.length > 0 ? sport : "sports") + ".svg";
}

function label(value) {
    const sport = normalizedSport(value);
    const labels = {
        "american-football": "American Football",
        "baseball": "Baseball",
        "basketball": "Basketball",
        "cricket": "Cricket",
        "football": "Football",
        "hockey": "Hockey",
        "snooker": "Snooker",
        "tennis": "Tennis",
        "volleyball": "Volleyball"
    };
    return labels[sport] || "Sports";
}
