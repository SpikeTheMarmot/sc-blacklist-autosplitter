// Tom Clancy's Splinter Cell Blacklist Autosplitter by Spike & Butt4cak3
// Please contact Spike or Butt4cak3 in case you find a bug or have suggestions for improvements.
// You can also create an issue and/or open a PR.

state("Blacklist_game")
{
    int levelID: 0x2E392A8;
    float gameUptime: 0x2FC5AC8;
    bool isLoading: 0x2ECEDBC, 0x0, 0x29;
    bool isInLoadScreen: 0x2EB5A18;
    bool isRestarting: 0x2EB5D4E;                               // also true when in load screens
    bool isMissionCompleted: 0x2ED054C, 0x34, 0x0;
    bool isNotInCutscene: 0x2EB5DDC, 0x38, 0x1F0, 0xC0, 0xADC;  // is buggy if you keep input pressed while the cutscene ends
    bool isInCutscene1: 0x2ECEDBC, 0x0, 0x28;
    bool isInCutscene2: 0x2EB5DBC, 0x18474;
    bool hasControl: 0x2ECE460, 0x4, 0x4C, 0x1A8, 0x40;         // hasControl can be true for some time before cutscenes
}

startup
{
    settings.Add("startWhenGettingControl", true, "Start timer when getting control");
    settings.SetToolTip("startWhenGettingControl", "Start the timer when you get control instead of when the load finishes.");
    settings.CurrentDefaultParent = "startWhenGettingControl";
    settings.Add("startWhenGettingControl_Sh", true, "Safehouse (Starts when the voice line triggers)");
    settings.SetToolTip("startWhenGettingControl_Sh", "Starts the timer when the voice line \"Grim, gimme a sitrep.\" triggers.");
    settings.Add("startWhenGettingControl_HS", true, "Hawkins Seafort");
    settings.Add("startWhenGettingControl_OF", true, "Opium Farm");
    settings.Add("startWhenGettingControl_PE", true, "Pakistani Embassy");
    settings.Add("startWhenGettingControl_SC", true, "Smugglers Compound");
    settings.CurrentDefaultParent = null;

    settings.Add("resetWhenRestarting", false, "Reset timer when mission restarts (needs \"Reset\" to be enabled)");
    settings.SetToolTip("resetWhenRestarting", "Reset the timer when the mission restarts. This is useful for IL runs.");

    settings.Add("splitOnMissionEnd", false, "Split on mission end instead of when loading starts in the After Action Report.");
    settings.SetToolTip("splitOnMissionEnd", "Could be useful for IL runs. Does not work with multiple splits.");

    settings.Add("syncWithIngameTime", false, "Sync timer with actual game time");
    settings.SetToolTip("syncWithIngameTime", "The timer will run with the actual speed the game runs at.");

    vars.paladinLevelID = 59;
    vars.mpLobbyLevelID = 181;
    vars.safehouseLevelID = 172;
    vars.hawkinsSeafortLevelID = 38;
    vars.opiumFarmLevelID = 106;
    vars.pakistaniEmbassyLevelID = 205;
    vars.smugglersCompoundLevelID = 132;
    vars.siteFLevelID = 171;
    vars.startTime = 0.0;           // gameUptime when the timer was started
    vars.timeLoading = 0.0;         // accumulated loading time
    vars.isInCutscene = false;
}

update
{
    vars.isInCutscene = current.isInCutscene1 || current.isInCutscene2;
    vars.oldIsInCutscene = old.isInCutscene1 || old.isInCutscene2;
}

gameTime
{
    // do not sync timer with ingame time when the setting is disabled
    if (!settings["syncWithIngameTime"]) {
        return null;
    }
    double time = current.gameUptime - vars.startTime - vars.timeLoading;
    return TimeSpan.FromSeconds(time);
}

isLoading
{
    if (current.isLoading) {
        // add frame time to accumulated loading time
        vars.timeLoading += current.gameUptime - old.gameUptime;
    }

    if (settings["syncWithIngameTime"]) {
        // always report actual game time
        return true;
    } else {
        return current.isLoading;
    }
}

start
{
    vars.startTime = current.gameUptime;
    vars.timeLoading = 0f;

    // the levelID is zero on game startup
    bool isInMission = current.levelID > 0
        && current.levelID != vars.paladinLevelID
        && current.levelID != vars.mpLobbyLevelID;

    // if option is not enabled start when loading completes
    if (!settings["startWhenGettingControl"]) {
        return isInMission && !current.isLoading && old.isLoading;
    }

    if (settings["startWhenGettingControl_HS"] && current.levelID == vars.hawkinsSeafortLevelID
      || settings["startWhenGettingControl_OF"] && current.levelID == vars.opiumFarmLevelID
      || settings["startWhenGettingControl_PE"] && current.levelID == vars.pakistaniEmbassyLevelID
      || settings["startWhenGettingControl_SC"] && current.levelID == vars.smugglersCompoundLevelID) {
        // we are in a level for which the option is enabled
        bool gotControl = current.hasControl && !vars.isInCutscene && (vars.oldIsInCutscene || !old.hasControl);
        return isInMission && !current.isRestarting && gotControl;

    } else if (settings["startWhenGettingControl_Sh"] && current.levelID == vars.safehouseLevelID) {
        // we start as soon as the voice line triggers
        bool gotControl = current.isNotInCutscene && !old.isNotInCutscene;
        return isInMission && !current.isRestarting && gotControl;

    } else {
        return isInMission && !current.isLoading && old.isLoading;
    }
}

split
{
    if (settings["splitOnMissionEnd"]) {
        return current.isMissionCompleted;
    } else {
        // split on load after the mission ended
        // TODO: end split on first frame of the cutscene with the knife in the snow
        bool startedLoading = current.isLoading && !old.isLoading;
        return current.isMissionCompleted && startedLoading;
    }
}

reset
{
    if (settings["resetWhenRestarting"]) {
        bool startedRestarting = current.isRestarting && !old.isRestarting;
        return startedRestarting && !current.isMissionCompleted && !current.isInLoadScreen;
    };
}
