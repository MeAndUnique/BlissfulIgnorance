--
-- Please see the license.txt file included with this distribution for
-- attribution and copyright information.
--

local checkReductionTypeHelperOriginal;
local checkNumericalReductionTypeHelperOriginal;
local getDamageAdjustOriginal;
local applyDamageOriginal;
local messageDamageOriginal;

local rActiveTarget;
local bAdjusted = false;
local bIgnored = false;
local bPreventCalculateRecursion = false;
local nAbsorbed = 0;

function onInit()
	checkReductionTypeHelperOriginal = ActionDamage.checkReductionTypeHelper;
	ActionDamage.checkReductionTypeHelper = checkReductionTypeHelper;

	checkNumericalReductionTypeHelperOriginal = ActionDamage.checkNumericalReductionTypeHelper;
	ActionDamage.checkNumericalReductionTypeHelper = checkNumericalReductionTypeHelper;

	getDamageAdjustOriginal = ActionDamage.getDamageAdjust;
	ActionDamage.getDamageAdjust = getDamageAdjust;

	applyDamageOriginal = ActionDamage.applyDamage;
	ActionDamage.applyDamage = applyDamage;

	messageDamageOriginal = ActionDamage.messageDamage;
	ActionDamage.messageDamage = messageDamage;

	if EffectsManagerBCEDND then
		EffectsManagerBCEDND.processAbsorb = function() end;
	end
end

function checkReductionTypeHelper(rMatch, aDmgType)
	local result = checkReductionTypeHelperOriginal(rMatch, aDmgType);
	if bPreventCalculateRecursion then
		return result;
	end

	if result then
		if ActionDamage.checkNumericalReductionType(rActiveTarget.tReductions["ABSORB"], aDmgType) ~= 0 then
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
			result = not ActionDamage.checkReductionType(rActiveTarget.tReductions["RESIST"], aDmgType) and
				not ActionDamage.checkReductionType(rActiveTarget.tReductions["IMMUNE"], aDmgType) and
				not ActionDamage.checkReductionType(rActiveTarget.tReductions["ABSORB"], aDmgType);
			bPreventCalculateRecursion = false;
		end
	elseif rMatch and (rMatch.mod ~= 0) then
		if rMatch.sDemotedFrom then
			local aMatches = rActiveTarget.tReductions[rMatch.sDemotedFrom];
			bPreventCalculateRecursion = true;
			result = ActionDamage.checkReductionType(aMatches, aDmgType) or
				ActionDamage.checkNumericalReductionType(aMatches, aDmgType) ~= 0;
			bPreventCalculateRecursion = false;
		end
	end

	return result;
end

function checkNumericalReductionTypeHelper(rMatch, aDmgType, nLimit)
	local nMod;
	local aNegatives;
	if rMatch and rMatch.nReduceMod then
		nMod = rMatch.mod;
		aNegatives = rMatch.aNegatives;
		rMatch.mod = rMatch.nReduceMod;
		rMatch.aNegatives = rMatch.aReduceNegatives;
	end
	local result = checkNumericalReductionTypeHelperOriginal(rMatch, aDmgType, nLimit);
	if nMod then
		rMatch.nReduceMod = rMatch.mod;
		rMatch.aReduceNegatives = rMatch.aNegatives;
		rMatch.mod = nMod;
		rMatch.aNegatives = aNegatives;
	end


	if bPreventCalculateRecursion then
		return result;
	end

	if result ~= 0 then
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
	if rMatch and rMatch.bIsAbsorb then
		rMatch.nApplied = 0;
	end
	return result;
end

function getDamageAdjust(rSource, rTarget, nDamage, rDamageOutput)
	rActiveTarget = rTarget;
	rTarget.tReductions = {
		["VULN"] = {},
		["RESIST"] = {},
		["IMMUNE"] = {},
		["ABSORB"] = {},
	};

	multiplyDamage(rSource, rTarget, rDamageOutput);

	local nDamageAdjust, bVulnerable, bResist = getDamageAdjustOriginal(rSource, rTarget, rDamageOutput.nVal, rDamageOutput);

	local tUniqueTypes = {};
	for k, v in pairs(rDamageOutput.aDamageTypes) do
		-- Get individual damage types for each damage clause
		local aSrcDmgClauseTypes = {};
		local aTemp = StringManager.split(k, ",", true);
		for _,vType in ipairs(aTemp) do
			if vType ~= "untyped" and vType ~= "" then
				table.insert(aSrcDmgClauseTypes, vType);
			end
		end

		local nLocalAbsorb = ActionDamage.checkNumericalReductionType(rTarget.tReductions["ABSORB"], aSrcDmgClauseTypes);
		if nLocalAbsorb ~= 0 then
			nDamageAdjust = nDamageAdjust - (v * nLocalAbsorb);
			for _,sDamageType in ipairs(aSrcDmgClauseTypes) do
				if sDamageType:sub(1,1) ~= "!" and sDamageType:sub(1,1) ~= "~" then
					tUniqueTypes[sDamageType] = true;
				end
			end
		end
	end
	nAbsorbed = nDamage + nDamageAdjust;

	local aAbsorbed = {};
	for sDamageType,_ in pairs(tUniqueTypes) do
		table.insert(aAbsorbed, sDamageType);
	end
	if #aAbsorbed > 0 then
		table.sort(aAbsorbed);
		table.insert(rDamageOutput.tNotifications, "[ABSORBED: " .. table.concat(aAbsorbed, ",") .. "]");
	end

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

function multiplyDamage(rSource, rTarget, rDamageOutput)
	local nMult = 1;
	local bRateEffect = false;
	for _,rEffect in ipairs(EffectManager5E.getEffectsByType(rSource, "DMGMULT", nil, rTarget)) do
		nMult = nMult * rEffect.mod;
		bRateEffect = true;
	end
	if not bRateEffect then
		return;
	end

	table.insert(rDamageOutput.tNotifications, "[MULTIPLIED: " .. nMult .. "]");

	local nCarry = 0;
	for kType, nType in pairs(rDamageOutput.aDamageTypes) do
		local nAdjusted = nType * nMult;
		nCarry = nCarry + nAdjusted % 1;
		if nCarry >= 1 then
			nAdjusted = nAdjusted + 1;
			nCarry = nCarry - 1;
		end
		rDamageOutput.aDamageTypes[kType] = math.floor(nAdjusted);
	end
	rDamageOutput.nVal = math.max(math.floor(rDamageOutput.nVal * nMult), 1);
end

function applyDamage(rSource, rTarget, vRollOrSecret, sDamage, nTotal)
	if type(vRollOrSecret) == "table" then
		sDamage = vRollOrSecret.sDesc;
		nTotal = vRollOrSecret.nTotal;
	end

	if string.match(sDamage, "%[RECOVERY")
		or string.match(sDamage, "%[HEAL")
		or nTotal < 0 then
			local sType = "heal"
			if string.match(sDamage, "%[RECOVERY") then
				sType = "hitdice";
			end
			if EffectManager5E.hasEffectCondition(rTarget, "UNHEALABLE")
			or #(EffectManager5E.getEffectsByType(rTarget, "UNHEALABLE", {sType})) > 0 then
				nTotal = 0;
				sDamage = sDamage .. "[UNHEALABLE]";
			else
				local nMult = 1;
				local bRateEffect = false;
				for _,rEffect in ipairs(EffectManager5E.getEffectsByType(rSource, "HEALMULT", {sType}, rTarget)) do
					nMult = nMult * rEffect.mod;
					bRateEffect = true;
				end
				for _,rEffect in ipairs(EffectManager5E.getEffectsByType(rTarget, "HEALEDMULT", {sType}, rSource)) do
					nMult = nMult * rEffect.mod;
					bRateEffect = true;
				end
				if bRateEffect then
					nTotal = math.floor(nTotal * nMult);
					sDamage = sDamage .. "[MULTIPLIED: " .. nMult .."]";
				end
			end
	end

	applyDamageOriginal(rSource, rTarget, vRollOrSecret, sDamage, nTotal);
end

function messageDamage(rSource, rTarget, vRollOrSecret, sDamageText, sDamageDesc, sTotal, sExtraResult)
	if type(vRollOrSecret) == "table" then
		local rRoll = vRollOrSecret;
		sDamageText = rRoll.sDamageText;
		sDamageDesc = rRoll.sDesc;
		sTotal = rRoll.nTotal;
		sExtraResult = rRoll.sResults;
	end

	if nAbsorbed < 0 then
		local nDamage = nAbsorbed;
		nAbsorbed = 0;
		ActionDamage.applyDamage(rSource, rTarget, vRollOrSecret, sDamageText, nDamage);
	else
		if string.match(sDamageDesc, "%[UNHEALABLE") then
			if sExtraResult ~= "" then
				sExtraResult = sExtraResult .. " ";
			end
			sExtraResult = sExtraResult .. " [UNHEALABLE]";
		end
		local sMult = string.match(sDamageDesc, "%[MULTIPLIED: [^%]]+%]");
		if sMult then
			sExtraResult = sExtraResult .. sMult;
		end
		messageDamageOriginal(rSource, rTarget, vRollOrSecret, sDamageText, sDamageDesc, sTotal, sExtraResult);
	end
end