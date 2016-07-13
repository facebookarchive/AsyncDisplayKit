### Contribute to ASDK's Friendly Reputation

ASDK has earned its reputation as an exceptionally welcoming place for newbie & experienced developers alike through the extra time Scott takes to thank _everyone_ who posts a question, bug, feature request or PR, for their time and contribution to the project, no matter how large the contribution (or silly the question).

###PR Reviewing

Merge permissions granted to Scott Goodson (@appleguy), Michael Schneider (@maicki), Adlai Holler (@Adlai-Holler)

**PR Type** | **Required Reviewers**
--- | --- 
Documentation | Anyone
Bug Fix | 2 (external PR) or 1 (internal PR) of the following (Scott, Michael, Adlai, Levi)
Refactoring | 1-3 depending on size / author familiarity with feature
New API | Scott + component owner + 1 additional
Breaking API | Scott + component owner + 1 additional

**Component** | **Experts For Reviewing**
--- | --- 
ASTextNode + subclasses | Ricky / Oliver
ASImageNode + subclasses | Garrett / Scott / Michael
ASDataController / Table / Collection | Michael
ASRangeController | Scott
ASLayout | Huy
ASDisplayNode | Garret / Michael / Levi
ASVideoNode | #asvideonode channel

###PR Merging

BE CAUTIOUS, DON'T CAUSE A REGRESSION

Try to include as much as possible:
- Description / Screenshots
- Motivation & Context
- Methods of testing / Sample app
- What type of change it is (bug fix, new feature, breaking change) 
- Tag @hannahmbanana on any documentation needs* 
- Title the PR with the component in brackets - e.g. "[ASTextNode] fix threading issues..."
- New files need to include the required Facebook licensing header info.  
- For future viewers / potential contributors, try to describe why this PR is helpful / useful / awesome / makes an impact on the current or future community

###What stays on GitHub vs goes to Ship? 

GitHub:
- active bugs
- active community discussions
- unresolved community questions
- open issue about slack channel
- open issue with list of “up-for-grabs” tasks to get involved

Ship:
- feature requests
- documentation requests
- performance optimizations / refactoring

Comment for moving to Ship:

@\<FEATURE_REQUESTOR\> The community is planning an exciting long term road map for the project and getting organized around how to deliver these feature requests.

If you are interested in helping contribute to this component or any other, don’t hesitate to send us an email at AsyncDisplayKit@gmail.com or ping us on <a href="https://github.com/facebook/AsyncDisplayKit/issues/1582">
ASDK's Slack</a> channel. If you would like to contribute for a few weeks, we can also add you to our Ship bug tracker so that you can see what everyone is working on and actively coordinate with us. 

As always, keep filing issues and submitting pull requests here on Github and we will only move things to the new tracker if they require long term coordination. 
