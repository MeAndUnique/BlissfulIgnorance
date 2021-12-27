-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local getReductionTypeOriginal;
local checkReductionTypeHelperOriginal;
local checkNumericalReductionTypeHelperOriginal;
local getDamageAdjustOriginal;
local messageDamageOriginal;

local sResistanceMessage;
local tReductions = {};
local bPreventCalculateRecursion = false;
local nAbsorbed = 0;

function onInit()
	getReductionTypeOriginal = ActionDamage.getReductionType;
	ActionDamage.getReductionType = getReductionType;

	checkReductionTypeHelperOriginal = ActionDamage.checkReductionTypeHelper;
	ActionDamage.checkReductionTypeHelper = checkReductionTypeHelper;

	checkNumericalReductionTypeHelperOriginal = ActionDamage.checkNumericalReductionTypeHelper;
	ActionDamage.checkNumericalReductionTypeHelper = checkNumericalReductionTypeHelper;

	getDamageAdjustOriginal = ActionDamage.getDamageAdjust;
	ActionDamage.getDamageAdjust = getDamageAdjust;

	messageDamageOriginal = ActionDamage.messageDamage;
	ActionDamage.messageDamage = messageDamage;
end

function getReductionType(rSource, rTarget, sEffectType)
	local aFinal = getReductionTypeOriginal(rSource, rTarget, sEffectType);

	local bIgnoreAll = false;
	local aEffects = EffectManager5E.getEffectsByType(rSource, "IGNORE" .. sEffectType, {}, rTarget);
	for _,rEffect in pairs(aEffects) do
		for _,sType in pairs(rEffect.remainder) do
			if sType == "all" then
				for _,sDamage in ipairs(DataCommon.dmgtypes) do
					addIgnoredDamageType(aFinal, sDamage);
				end
				bIgnoreAll = true;
				break;
			end
			addIgnoredDamageType(aFinal, sType);
		end
		if bIgnoreAll then
			break;
		end
	end

	if sEffectType == "IMMUNE" and aFinal["all"] then
		local rReduction = aFinal["all"];
		aFinal["all"] = nil;
		for _,sDamage in ipairs(DataCommon.dmgtypes) do
			aFinal[sDamage] = rReduction;
		end
	end

	if sEffectType == "RESIST" then -- Represents the last set
		local aAbsorb = getReductionType(rSource, rTarget, "ABSORB");
		Debug.chat(EffectManager5E.getEffectsByType(rTarget, "ABSORB", {}, rSource), aAbsorb)
		for _,rAbsorb in pairs(aAbsorb) do
			if rAbsorb.mod == 0 then
				rAbsorb.mod = 1;
			end
			rAbsorb.mod = rAbsorb.mod + 1;
		end

		local bDemoteAll = false;
		aEffects = EffectManager5E.getEffectsByType(rSource, "DEMOTEIMMUNE", {}, rTarget);
		for _,rEffect in pairs(aEffects) do
			for _,sType in pairs(rEffect.remainder) do
				if sType == "all" then
					for _,sDamage in ipairs(DataCommon.dmgtypes) do
						addDemotedDamagedType(aFinal, tReductions["IMMUNE"], sDamage, "IMMUNE");
					end
					bDemoteAll = true;
					break;
				end
				addDemotedDamagedType(aFinal, tReductions["IMMUNE"], sType, "IMMUNE");
			end
			if bDemoteAll then
				break;
			end
		end

		bDemoteAll = false;
		aEffects = EffectManager5E.getEffectsByType(rSource, "DEMOTEABSORB", {}, rTarget);
		for _,rEffect in pairs(aEffects) do
			for _,sType in pairs(rEffect.remainder) do
				if sType == "all" then
					for _,sDamage in ipairs(DataCommon.dmgtypes) do
						addDemotedDamagedType(tReductions["IMMUNE"], tReductions["ABSORB"], sDamage, "ABSORB");
					end
					bDemoteAll = true;
					break;
				end
				addDemotedDamagedType(tReductions["IMMUNE"], tReductions["ABSORB"], sType, "ABSORB");
			end
			if bDemoteAll then
				break;
			end
		end

		local bMakeAllVulnerable = false;
		aEffects = EffectManager5E.getEffectsByType(rSource, "MAKEVULN", {}, rTarget);
		for _,rEffect in pairs(aEffects) do
			for _,sType in pairs(rEffect.remainder) do
				if sType == "all" then
					for _,sDamage in ipairs(DataCommon.dmgtypes) do
						addVulnerableDamageType(tReductions["VULN"], sDamage);
					end
					bMakeAllVulnerable = true;
					break;
				end
				addVulnerableDamageType(tReductions["VULN"], sType);
			end
			if bMakeAllVulnerable then
				break;
			end
		end
	end

	tReductions[sEffectType] = aFinal;
	return aFinal;
end

function addIgnoredDamageType(aEffects, sDamageType)
	local rReduction = aEffects[sDamageType];
	if rReduction then
		if not rReduction.aIgnored then
			rReduction.aIgnored = {};
		end
		table.insert(rReduction.aIgnored, sDamageType);
	end

	rReduction = aEffects["all"];
	if rReduction then
		if not rReduction.aIgnored then
			rReduction.aIgnored = {};
		end
		table.insert(rReduction.aIgnored, sDamageType);
	end
end

function addDemotedDamagedType(aDemotedEffects, aBaseEffects, sDamageType, sOriginal)
	local rReduction = aBaseEffects[sDamageType];
	if rReduction and not (rReduction.aIgnored and StringManager.contains(rReduction.aIgnored, sDamageType)) then
		rReduction.bDemoted = true;

		local rDemoted = aDemotedEffects[sDamageType];
		if not rDemoted then
			rDemoted = {
				mod = 0;
				aNegatives = {}
			};
			aDemotedEffects[sDamageType] = rDemoted;
		end
		
		rDemoted.sDemotedFrom = "sOriginal";
	end

	rReduction = aBaseEffects["all"];
	if rReduction then
		rReduction.bDemoted = true;

		local rDemoted = aDemotedEffects[sDamageType];
		if not rDemoted then
			rDemoted = {
				mod = 0;
				aNegatives = {}
			};
			aDemotedEffects[sDamageType] = rDemoted;
		end
		
		rDemoted.sDemotedFrom = "sOriginal";
	end
end

function addVulnerableDamageType(aEffects, sDamageType)
	aEffects[sDamageType] = {
		mod = 0,
		aNegatives = {},
		bAddIfUnresisted = true
	};
end

function checkReductionTypeHelper(rMatch, aDmgType)
	local result = checkReductionTypeHelperOriginal(rMatch, aDmgType);
	if bPreventCalculateRecursion then
		return result;
	end

	if result then
		if ActionDamage.checkReductionType(tReductions["ABSORB"], aDmgType) then
			result = false;
		elseif rMatch.aIgnored then
			for _,sIgnored in pairs(rMatch.aIgnored) do
				if StringManager.contains(aDmgType, sIgnored) then
					sResistanceMessage ="[RESISTANCE IGNORED]";
					result = false;
					break;
				end
			end
		elseif rMatch.bDemoted then
			sResistanceMessage ="[RESISTANCE DEMOTED]";
			result = false;
		elseif rMatch.bAddIfUnresisted then
			bPreventCalculateRecursion = true;
			result = not ActionDamage.checkReductionType(tReductions["RESIST"], aDmgType) and
				not ActionDamage.checkReductionType(tReductions["IMMUNE"], aDmgType) and
				not ActionDamage.checkReductionType(tReductions["ABSORB"], aDmgType);
			bPreventCalculateRecursion = false;
		end
	elseif rMatch and (rMatch.mod ~= 0) and rMatch.sDemotedFrom then
		local aMatches = tReductions[rMatch.sDemotedFrom];
		result = ActionDamage.checkReductionType(aMatches, aDmgType)
	end

	return result;
end

function checkNumericalReductionTypeHelper(rMatch, aDmgType, nLimit)
	local result = checkNumericalReductionTypeHelperOriginal(rMatch, aDmgType, nLimit);
	if (result ~= 0) and rMatch.aIgnored and #rMatch.aIgnored > 0 then
		for _,sIgnored in pairs(rMatch.aIgnored) do
			if StringManager.contains(aDmgType, sIgnored) then
				sResistanceMessage ="[RESISTANCE IGNORED]";
				return 0;
			end
		end
	end
	return result;
end

function getDamageAdjust(rSource, rTarget, nDamage, rDamageOutput)
	tReductions = {
		["VULN"] = {},
		["RESIST"] = {},
		["IMMUNE"] = {},
		["ABSORB"] = {},
	};

	-- get absorb entries
		-- timing probably doesnt matter? (defult to after resist gatehred)
	-- when checking other types, also check to see if damage absorbed.
		-- move recursion prevention closer to vuln check
	-- after normal calc, calc absorb
		-- dont forget to allow mod value as multiplier
	-- if absorbing more than total damage, prevent damage message
		-- and call applyDamage with amount to heal (negative damage)
			-- annotate with [ABSORBED]

	local nDamageAdjust, bVulnerable, bResist = getDamageAdjustOriginal(rSource, rTarget, rDamageOutput.nVal, rDamageOutput);

	for k, v in pairs(rDamageOutput.aDamageTypes) do
		-- Get individual damage types for each damage clause
		local aSrcDmgClauseTypes = {};
		local aTemp = StringManager.split(k, ",", true);
		for _,vType in ipairs(aTemp) do
			if vType ~= "untyped" and vType ~= "" then
				table.insert(aSrcDmgClauseTypes, vType);
			end
		end

		local nLocalAbsorb = ActionDamage.checkNumericalReductionType(tReductions["ABSORB"], aSrcDmgClauseTypes);
		if nLocalAbsorb ~= 0 then
			nDamageAdjust = nDamageAdjust - (v * nLocalAbsorb);
		end
	end
	nAbsorbed = nDamage + nDamageAdjust;

	-- todo bools for message additions, allowing multiples
	if sResistanceMessage then
		table.insert(rDamageOutput.tNotifications, sResistanceMessage);
		sResistanceMessage = nil;
	end

	return nDamageAdjust, bVulnerable, bResist;
end

function messageDamage(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult)
	if nAbsorbed < 0 then
		local nDamage = nAbsorbed;
		nAbsorbed = 0;
		ActionDamage.applyDamage(rSource, rTarget, bSecret, sDamageType, nDamage);
	else
		messageDamageOriginal(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult);
	end
end