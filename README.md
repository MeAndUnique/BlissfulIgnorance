# Blissful Ignorance
A Fantasy Grounds extension that adds effects for extra functionality around damage resistance and immunity.

The following targetable Effects have been added:
* **ABSORB: (n), types** - When the target takes damage from one of the provided damage types, they instead are healed for n times the damage. n is optional and defaults to 1. e.g. "ABSORB: lightning" may be used for a shambling mound.
* **IGNORE[R]: types** - Damage dealt by the bearer of this effect will ignore R to any of the damage types, where R can be one of ABSORB, IGNORE, RESIST, or VULN. e.g. "IGNORERESIST: fire" for a Fire Elemental Adept.
* **[R1]TO[R2]: types** - Damage dealt by the bearer of this effect will treat R1 as R2 for any of the damage types, where R1 and R2 may be one of ABSORB, IGNORE, RESIST, or VULN. e.g. "IMMUNETORESIST: radiant" would cause the damage dealt by a paladin's divine smite to treat radiant immunity as radiant resistance instead.
* **MAKEVULN: types** - Damage dealt by the bearer of this effect will treat a creature without any sort of resistance to the damage types as if they were vulnerable. e.g. "MAKEVULN: slashing" would cause a wraith to take double damage from magic swords, but still take half damage from nonmagical, unsilvered swords.
* **REDUCE: n, types** - This functions exactly as RESIST: n, except it will also stack with normal resistance.
* **UNHEALABLE: (types)** - The bearer of this effect cannot benefit from any healing of the associated types. types is optional and may be any combination of "heal", "hitdice", and "rest", seperated by commas. If types is not provided, then all types of healing are prevented.
* **DMGMULT: n** - The bearer of this effect has all of their damage dealt multiplied by n.
* **HEALMULT: n** - The bearer of this effect has all of their healing done multiplied by n.
* **HEALEDMULT: n, (types)** - The bearer of this effect has all of their healing received multiplied by n. types is optional and may be any combination of "heal", "hitdice", and "rest", seperated by commas. If types is not provided, then all types of healing are multiplied.

## Installation
Download [BlissfulIgnorance.ext](https://github.com/MeAndUnique/BlissfulIgnorance/releases) and place in the extensions subfolder of the Fantasy Grounds data folder.

## Attribution
SmiteWorks owns rights to code sections copied from their rulesets by permission for Fantasy Grounds community development.
'Fantasy Grounds' is a trademark of SmiteWorks USA, LLC.
'Fantasy Grounds' is Copyright 2004-2021 SmiteWorks USA LLC.

<a href="https://www.vecteezy.com/">Vectors by Vecteezy</a>