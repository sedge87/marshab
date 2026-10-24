# Achievements: first draft for discussion

A draft only. Nothing is built yet. Each achievement has a name, its caption (shown when you unlock it), and what triggers it.

## How they work
- **Across saves.** Unlocks live in one file (`user://achievements.cfg`) beside the settings, not in a save. A player keeps them however many colonies they start.
- **Shown as a toast** in the habitat's voice, with a small chime, plus an Achievements page in the pause menu and title screen. Locked ones show their name greyed out. Secret ones show "???" until found.
- **Built on events, not checks.** Each system announces what happened (a room sealed, a storm ended, GAR-Y finished a job), and one small achievements script listens. When we add a mechanic, its achievements are a few lines with no rework. When we change one, only its own achievements move.
- **Never for being unkind or breaking things on purpose.** Failure achievements exist, but they are gentle jokes about surviving a mishap, never a reward for causing one.
- **Not in Mission mode until a mission is passed or failed.** Achievements shouldn't distract from a Test. Free play earns them freely.

**Status tags:**
- **Ready:** the mechanic exists now.
- **Waits:** the mechanic is still being built (sleep, pick-up, ladders, dust on panels, item interactions). These are kept in the list so the set feels whole, and switched on when their mechanic lands.

## First steps
| Name | Caption | Trigger | Status |
|---|---|---|---|
| One Small Step | "That's one small step for a commander, one giant leap for the colony." | Walk on Mars for the first time | Ready |
| Hello, Neighbour | "The view is incredible. The neighbours are very quiet." | Land at any site | Ready |
| Room With a View | "Prime real estate. 225 million kilometres from the nearest café." | Glaze your first window | Ready |
| Airtight Alibi | "Sealed, pressurised and absolutely not leaking. Probably." | Seal your first room | Ready |
| Home Sweet Dome | "Wipe your boots. Seriously, the dust gets everywhere." | Build a room, an airlock and power, and step inside | Ready |
| Ink Stained | "The colony has a logo. Merchandise pending." | Choose a colony emblem | Ready |

## Building
| Name | Caption | Trigger | Status |
|---|---|---|---|
| Urban Sprawl | "Planning permission? On Mars? Never heard of it." | Have 10 rooms at once | Ready |
| Hallway Enthusiast | "Some people collect stamps." | Build 50 m of corridor | Ready |
| Feng Shui Master | "The chi flows. So does the oxygen." | Furnish every room in the base | Ready |
| Sun Worshipper | "The panels love you. The panels need you." | Have 20 solar panels | Ready |
| Glasshouse | "Lovely light. Terrible for hide-and-seek." | Glaze 12 windows | Ready |
| Sign of the Times | "Words, on a wall, on Mars." | Write your own text on a panel | Ready |
| Roof Inspector | "Nice view. Mind the edge." | Climb a ladder onto the roof | Waits (ladders) |
| Wrapped Up Warm | "Radiation can't touch this." | Shield every outer wall of a room | Waits (wall shielding) |

## Surviving Mars
| Name | Caption | Trigger | Status |
|---|---|---|---|
| Weathered It | "It was only a little dust. A planet's worth of little dust." | Get through a dust storm with power on | Ready |
| Snow Day | "Carbon dioxide snow. Do not build a snowman." | See CO₂ snow fall at the ice site | Ready |
| Batten Down | "Solar particle event: zero sunburn." | Shelter the whole crew through a solar particle event | Ready |
| Lights Out, Calm Heads | "Blackout? We prefer 'unscheduled stargazing'." | Recover from a blackout without losing anyone | Ready |
| Patch Job | "Duct tape: the most important tool in the solar system." | Fix a hull breach | Ready |
| The Long Haul | "A whole Martian year. You've earned a birthday cake." | Reach sol 669 in one colony | Ready |
| Dusty Panels | "You cleaned the panels. They sparkle. They thank you." | Clean dust off a solar panel | Waits (dust on panels) |

## Crew life
| Name | Caption | Trigger | Status |
|---|---|---|---|
| Green Thumb | "First Martian lettuce. It tastes like… lettuce. Amazing." | Harvest your first crop | Ready |
| Leg Day | "Bones stay strong in low gravity. Unlike excuses." | Keep the crew's fitness above 80% for 30 sols | Ready |
| Happy Campers | "Everyone's smiling. Even the robot." | Crew morale at maximum | Ready |
| Patched Up | "Plasters, plasters everywhere." | Treat an injury in the medical bay | Ready |
| Nap Champion | "Eight hours of solid sleep. The dream." | Sleep a full night | Waits (sleep) |
| Rudely Awakened | "Alarm at 3 a.m. Classic Mars." | Get woken by a critical alert | Waits (sleep) |
| Tidy Up | "A place for everything, and everything in its place." | Pick up and move 10 small items | Waits (pick-up) |

## GAR-Y
| Name | Caption | Trigger | Status |
|---|---|---|---|
| New Best Friend | "GAR-Y says hi. GAR-Y always says hi." | Meet GAR-Y | Ready |
| Delegation | "Why carry it yourself when you have a robot?" | Give GAR-Y 10 orders | Ready |
| Small But Mighty | "GAR-y is little. GAR-y is fierce. GAR-y is adorable." | Interact with mini GAR-y | Waits (GAR-y interaction) |
| Pat Pat Pat | "You patted GAR-Y 25 times. GAR-Y is overjoyed." | Pat GAR-Y 25 times (secret) | Waits (GAR-y interaction) |

## Missions
| Name | Caption | Trigger | Status |
|---|---|---|---|
| Mission Accomplished | "Mission Control is very proud. Mission Control may be crying." | Pass Mission 1 | Ready |
| Gold Star | "Every check green. Show-off." | Pass a Test with every check passed first try | Ready |
| Act One | "The habitat stands. Now to live in it." | Pass Missions 1–6 | Ready |
| Act Two | "People don't just survive here now. They live." | Pass Missions 7–10 | Ready |
| Try, Try Again | "Failure is just data with feelings." | Fail a Test, then pass it | Ready |
| Under Budget | "Accountants on Earth weep with joy." | Pass a mission using less than half the cargo | Ready |

## Explorer
| Name | Caption | Trigger | Status |
|---|---|---|---|
| Globetrotter | "Mars postcards collected: all of them." | Land at all four sites (across saves) | Ready |
| Rover Joyride | "Please return the rover with a full battery." | Drive 2 km in the rover | Ready |
| Through the Lens | "Observation camera online. Mars looks back." | Look through an observation camera | Ready |
| Night Owl | "Phobos and Deimos say hello." | Go outside at midnight | Ready |

## Secret and silly (still PG)
| Name | Caption | Trigger | Status |
|---|---|---|---|
| Rock Star | "Mars has never heard music like it. Mars has never heard music." | Play the guitar | Ready |
| Cuddle Protocol | "Plush morale: 100%." | Hug the plush toy | Ready |
| Door Enthusiast | "Open. Close. Open. Close. The airlock is filing a complaint." | Open and close the same door 20 times in a row | Ready |
| Wrong Way | "That's the cupboard, not the airlock." | Try to open an outer hatch with the inner door open | Ready |
| Space Is Big | "You walked 1 km in one go. Mars didn't get smaller." | Walk 1 km without stopping | Ready |

## Questions for you
1. **Mission mode:** should achievements unlock during a mission (after the Test), or in free play only?
2. **Shared view:** would it help to see a class's achievements, or should they stay personal to each player?
3. **Rewards:** stick to badges only? Or unlock small cosmetics, like new emblem colours or panel fonts? Cosmetics motivate players but add work.
4. **How many:** this is 47. We could trim to about 30 for launch and add more with each new mechanic.
