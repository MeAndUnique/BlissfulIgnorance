-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local getReductionTypeOriginal;
local checkReductionTypeHelperOriginal;
local checkNumericalReductionTypeHelperOriginal;
local getDamageAdjustOriginal;
local messageDamageOriginal;

local bAdjusted = false;
local bIgnored = false;
local tReductions = {};
local bPreventCalculateRecursion = false;
local nAbsorbed = 0;
local bIsAbsorbed = false;

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
	tReductions[sEffectType] = aFinal;

	addExtras(rSource, rTarget, "IGNORE" .. sEffectType, addIgnoredDamageType, sEffectType);

	if sEffectType == "IMMUNE" and aFinal["all"] then
		local rReduction = aFinal["all"];
		aFinal["all"] = nil;
		for _,sDamage in ipairs(DataCommon.dmgtypes) do
			aFinal[sDamage] = rReduction;
		end
	end

	if sEffectType == "RESIST" then -- Represents the last set
		local aAbsorb = getReductionType(rSource, rTarget, "ABSORB");
		for _,rAbsorb in pairs(aAbsorb) do
			if rAbsorb.mod == 0 then
				rAbsorb.mod = 1;
			end
			rAbsorb.mod = rAbsorb.mod + 1;
		end

		for sOriginalType,_ in pairs(tReductions) do
			for sNewType,_ in pairs(tReductions) do
				addExtras(rSource, rTarget, sOriginalType .. "TO" .. sNewType, addDemotedDamagedType, sOriginalType, sNewType);
			end
		end

		addExtras(rSource, rTarget, "MAKEVULN", addVulnerableDamageType);
	end

	return aFinal;
end

function addExtras(rSource, rTarget, sEffect, fAdd, sPrimaryReduction, sSecondaryReduction)
	local bHandledAll = false;
	local aEffects = EffectManager5E.getEffectsByType(rSource, sEffect, {}, rTarget);
	for _,rEffect in pairs(aEffects) do
		for _,sType in pairs(rEffect.remainder) do
			if sType == "all" then
				for _,sDamage in ipairs(DataCommon.dmgtypes) do
					fAdd(sDamage, sPrimaryReduction, sSecondaryReduction);
				end
				bHandledAll = true;
				break;
			end
			fAdd(sType, sPrimaryReduction, sSecondaryReduction);
		end
		if bHandledAll then
			break;
		end
	end
end

function addIgnoredDamageType(sDamageType, sIgnoredType)
	local aEffects = tReductions[sIgnoredType];
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

function addDemotedDamagedType(sDamageType, sOriginalType, sNewType)
	local aOriginalEffects = tReductions[sOriginalType];
	local aNewEffects = tReductions[sNewType]
	local rReduction = aOriginalEffects[sDamageType];
	if rReduction and not (rReduction.aIgnored and StringManager.contains(rReduction.aIgnored, sDamageType)) then
		rReduction.bDemoted = true;
		local rDemoted = getDemotedEffect(aNewEffects, sDamageType);
		rDemoted.sDemotedFrom = sOriginalType;
	end

	rReduction = aOriginalEffects["all"];
	if rReduction and not (rReduction.aIgnored and StringManager.contains(rReduction.aIgnored, sDamageType)) then
		rReduction.bDemoted = true;
		local rDemoted = getDemotedEffect(aNewEffects, sDamageType);
		rDemoted.sDemotedFrom = sOriginalType;
	end
end

function getDemotedEffect(aDemotedEffects, sDamageType)
	local rDemoted = aDemotedEffects[sDamageType];
	if not rDemoted then
		rDemoted = {
			mod = 0;
			aNegatives = {}
		};
		aDemotedEffects[sDamageType] = rDemoted;
	end
	return rDemoted;
end

function addVulnerableDamageType(sDamageType)
	local aEffects = tReductions["VULN"];
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
		if ActionDamage.checkNumericalReductionType(tReductions["ABSORB"], aDmgType) ~= 0 then
			result = false;
		elseif rMatch.aIgnored then
			for _,sIgnored in pairs(rMatch.aIgnored) do
				if StringManager.contains(aDmgType, sIgnored) then
					bIgnored = true;
					result = false;
					break;
				end
			end
		elseif rMatch.bDemoted then
			bAdjusted = true;
			result = false;
		elseif rMatch.bAddIfUnresisted then
			bPreventCalculateRecursion = true;
			result = not ActionDamage.checkReductionType(tReductions["RESIST"], aDmgType) and
				not ActionDamage.checkReductionType(tReductions["IMMUNE"], aDmgType) and
				not ActionDamage.checkReductionType(tReductions["ABSORB"], aDmgType);
			bPreventCalculateRecursion = false;
		end
	elseif rMatch and (rMatch.mod ~= 0) then
		if rMatch.sDemotedFrom then
			local aMatches = tReductions[rMatch.sDemotedFrom];
			bPreventCalculateRecursion = true;
			result = ActionDamage.checkReductionType(aMatches, aDmgType) or
				ActionDamage.checkNumericalReductionType(aMatches, aDmgType) ~= 0;
			bPreventCalculateRecursion = false;
		end
	end

	return result;
end

function checkNumericalReductionTypeHelper(rMatch, aDmgType, nLimit)
	local result = checkNumericalReductionTypeHelperOriginal(rMatch, aDmgType, nLimit);
	if bPreventCalculateRecursion then
		return result;
	end

	if (result ~= 0) then
		if rMatch.aIgnored then
			for _,sIgnored in pairs(rMatch.aIgnored) do
				if StringManager.contains(aDmgType, sIgnored) then
					bIgnored = true;
					result = 0;
				end
			end
		elseif rMatch.bDemoted then
			bAdjusted = true;
			result = 0;
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

	if bAdjusted then
		table.insert(rDamageOutput.tNotifications, "[RESISTANCE ADJUSTED]");
		bAdjusted = false;
	end
	if bIgnored then
		table.insert(rDamageOutput.tNotifications, "[RESISTANCE IGNORED]");
		bIgnored = false;
	end

	return nDamageAdjust, bVulnerable, bResist;
end

function messageDamage(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult)
	if nAbsorbed < 0 then
		local nDamage = nAbsorbed;
		nAbsorbed = 0;
		bIsAbsorbed = true;
		ActionDamage.applyDamage(rSource, rTarget, bSecret, sDamageType, nDamage);
	else
		if bIsAbsorbed then
			if sExtraResult ~= "" then
				sExtraResult = sExtraResult .. " ";
			end
			sExtraResult = sExtraResult .. "[ABSORBED]";
			bIsAbsorbed = false;
		end
		messageDamageOriginal(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult);
	end
end