"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const helpers_1 = require("./helpers");
// noinspection JSUnusedGlobalSymbols
/**
 * Converts a SAML mapped attribute, e.g. list of groups, to a cognito groups claim in the generated token
 * (groups claims are included in both id tokens and access tokens, where custom attributes only show in the id token)

 */
exports.handler = async (event) => {
    console.log('event ',event)
    event.response.claimsOverrideDetails = {
        groupOverrideDetails: {
            groupsToOverride: [
                // any existing groups the user may belong to
                ...event.request.groupConfiguration.groupsToOverride,
                // groups from the IdP (parses a single value, e.g. "[g1,g2]" into a string array, e.g ["g1","g2"])
                ...helpers_1.parseGroupsAttribute(event.request.userAttributes[helpers_1.getGroupsCustomAttributeName()])
            ]
        }
    };
    return event;
};
