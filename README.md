Heresy Addon for Turtle WoW CC2

This addon is highly specific for my purposes and likely will not be useful for anyone else unless modified. It's mainly uploaded to github just so I can keep version history in case I break something and need to roll back. It was primarily written using deepseek v3 AI, feeding in example code from the turtle wow api documentation to ensure everything works correctly

https://www.deepseek.com/

https://turtle-wow.fandom.com/wiki/API_Functions

Overview

Heresy is a custom addon designed to assist priests in World of Warcraft by automating various tasks such as healing, buffing, dispelling, and assisting party members. The addon is particularly useful for managing mana, healing party members, and providing support during combat.
Features

    Healing Automation: Automatically heals party members based on their health percentage.

    Buff Management: Buffs party members with spells like Power Word: Fortitude and Divine Spirit.

    Dispel and Cure Disease: Automatically dispels harmful debuffs and cures diseases from party members.

    Assist Mode: Assists party members by casting offensive spells like Smite, Shadow Word: Pain, and Mind Blast on their targets.

    Mana Management: Automatically drinks to restore mana when it is low and uses Quel'dorei Meditation in combat.

    Follow Party Member: Follows a designated party member when not engaged in combat or drinking.

Installation

    Download the Heresy.lua file.

    Place the file in your World of Warcraft Interface/AddOns directory.

    Rename the file to Heresy.lua if necessary.

    Restart World of Warcraft or use the /reload command to load the addon.

Usage

    Main Command: Use the /heresy command to trigger the addon's main functionality. This will check for healing needs, manage mana, buff party members, and assist in combat if assist mode is enabled.

    Assist Mode Toggle: Use the /heresyassist command to toggle assist mode on or off. When assist mode is on, the addon will assist party members by casting offensive spells on their targets.

Configuration

The addon comes with predefined thresholds and settings, but you can modify the following variables in the Heresy.lua file to suit your needs:

    DRINKING_MANA_THRESHOLD: The mana percentage at which the addon will stop drinking (default is 80%).

    EMERGENCY_HEALTH_THRESHOLD: The health percentage below which the addon will perform emergency healing even while drinking (default is 30%).

    HEALTH_THRESHOLD: The health percentage below which the addon will heal party members (default is 70%).

Notes

    The addon is designed to work with the priest class and assumes you have the necessary spells and abilities.

    Ensure you have the appropriate drinks in your inventory for mana restoration.

    The addon will announce in the party chat when it needs to drink after combat if mana is low.

Support

For any issues or suggestions, please contact the addon's author or submit an issue on the repository where you found this addon.
License

This addon is provided as-is, without any warranty. Feel free to modify and distribute it as you see fit.

Enjoy your time in Azeroth with the Heresy addon!
