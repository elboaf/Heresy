Heresy Addon for Turtle WoW CC2

![Example Image](https://i.imgur.com/C4YJis4.jpeg)

This addon is highly specific for my purposes and likely will not be useful for anyone else unless modified. It's mainly uploaded to github just so I can keep version history in case I break something and need to roll back. It was primarily written using deepseek v3 AI, feeding in example code from the turtle wow api documentation to ensure everything works correctly

https://www.deepseek.com/

https://turtle-wow.fandom.com/wiki/API_Functions

Overview

Heresy is a Lua-based addon for World of Warcraft designed to assist players, particularly Priests, in managing buffs, healing, dispelling, and combat assistance in a party or raid environment. The addon automates many tasks such as buffing party members, healing, dispelling debuffs, and assisting in combat by casting offensive spells on party members' targets.
Features

Automatic Buffing: Automatically buffs party members with spells like Power Word: Fortitude, Divine Spirit, and Shadow Protection.

Healing: Heals party members based on their health percentage, prioritizing emergency heals during combat.

Dispelling: Automatically dispels harmful debuffs from party members using Dispel Magic and Cure Disease.

Combat Assistance: Assists party members by casting offensive spells like Smite, Mind Blast, and Mind Flay on their targets.

Mana Management: Automatically drinks mana potions or uses Quel'dorei Meditation when mana is low.

Mount Management: Automatically mounts or dismounts based on the buff status of a designated party member (e.g., "Rele").

Levitate: Automatically casts Levitate when the player has the necessary feathers in their inventory.

Champion Buffing: Designates a champion and buffs them with Proclaim Champion and Champion's Grace.

Configuration

The addon is highly configurable through in-game slash commands and global variables. Key configuration options include:

Mana Thresholds: Set thresholds for when to start drinking, stop drinking, and use mana potions.

Health Thresholds: Set thresholds for when to heal party members and when to prioritize emergency heals.

Buff Throttling: Prevent excessive buffing by setting a cooldown duration between buffing cycles.

Assist Mode: Toggle combat assistance on or off.

Slash Commands

    /heresy: Main command to execute the addon's logic, including healing, buffing, and assisting.

    /heresyassist: Toggles assist mode on or off.

    /heresy-champ: Designates the currently targeted player as the champion.

    /heresy-rebuff: Resets the buffing throttle and immediately attempts to rebuff party members.

Installation

Download the Heresy.lua file.

Place the file in your World of Warcraft Interface/AddOns/Heresy directory.

Restart World of Warcraft or reload the UI.

The addon will be automatically loaded and ready to use.

Usage

Buffing: The addon will automatically buff party members when out of combat and mana is above the configured threshold.

Healing: The addon will heal party members based on their health percentage, prioritizing emergency heals during combat.

Dispelling: The addon will automatically dispel harmful debuffs from party members.

Combat Assistance: When assist mode is enabled, the addon will assist party members by casting offensive spells on their targets.

Mana Management: The addon will automatically drink mana potions or use Quel'dorei Meditation when mana is low.

Mount Management: The addon will automatically mount or dismount based on the buff status of a designated party member (e.g., "Rele").

Dependencies

QuickHeal: The addon relies on the QuickHeal_Priest_FindHealSpellToUse function for determining the appropriate healing spell to use. Ensure that QuickHeal is installed and functioning correctly.

Notes

The addon is designed for Priests but can be adapted for other classes with minor modifications.

The addon uses a throttling mechanism to prevent excessive buffing. Use the /heresy-rebuff command to manually reset the throttle if needed.

The addon assumes that the player has the necessary items (e.g., mana potions, feathers) in their inventory for certain functions (e.g., drinking, levitating).

License

This addon is released under the MIT License. Feel free to modify and distribute it as you see fit.
Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your changes.
Support

For support or to report issues, please open an issue on the GitHub repository.

Enjoy your time in Azeroth with Heresy!
