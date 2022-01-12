# DAT New Hire Setup

## Pre-requisites:
1. Okta fully configured

## Steps to start developing code
2. Installing Git
3. Setting up ssh keys with revision control software
4. Install Node
5. Install docker
6. Request access to AWS access 
   1. Roles: DATDeveloper-Freight and DATDeveloper-Network [Help Desk](https://transcore.jira.com/servicedesk/customer/portals)
7. Request access to Spotlight.io [Help Desk](https://transcore.jira.com/servicedesk/customer/portals)
8. Request access to xMatters [Help Desk](https://transcore.jira.com/servicedesk/customer/portals)
9. Download IDE of choice
   1. [VS Code](https://code.visualstudio.com)
   2. [IntelliJ IDEA](https://www.jetbrains.com/idea/)
      1. Licence required and can be requested [Help Desk](https://transcore.jira.com/servicedesk/customer/portals)
10. Jfrog setup
    1. Through [DAT Home](https://dat.okta.com/app/UserHome#) open Artifactory
    2. Follow steps in [Artifact/Container Repositories](https://transcore.jira.com/wiki/spaces/devops/pages/584090550?atlOrigin=eyJpIjoiMmRmNGIzMGUzNDk2NGY3MDgwNzEyYmM1ZDZmZTE2MjciLCJwIjoiYyJ9)
11. [Setup a Local Ambassador API Gateway](https://bitbucket.org/dat/ambassador-local/src/master/)

## Now you're ready... 
1. `git clone git@bitbucket.org:dat/truck-posting-service.git`
2. `cd truck-postin-service`
3. `npm run compose:test`


# Status Reports
## Sprint 67
- Walk through Angular.io tutorial
- Walk through Tour of Heros app
- Read Clean Code Chapter 4: Comments
- Read Clean Code, Chapter 5: Formatting
- Read Clean Code Chapter 6: Objects and Data Structures
- Peer programming SWAT-14 with Matt
- AWS Learning Needs Analysis Survey: https://amazonmr.au1.qualtrics.com/jfe/form/SV_eX6SsIDWxAeqeNM  (by September 14)
- Get truck-posting-service executing (for testing and development)
- Bug fix: Change TPS to use v4.4.3 as renovate attempted to updated but failed due to necessary Joi changes
