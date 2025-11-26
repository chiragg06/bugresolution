import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Static Resource
import BGG_IMAGE from '@salesforce/resourceUrl/bgg';

// Apex Controllers
import exchangeAuthorizationCode from '@salesforce/apex/DemoJIRASyncController.exchangeAuthorizationCode';
import checkTokenValidity from '@salesforce/apex/DemoJIRASyncController.checkTokenValidity';

export default class LoginIntroSection extends NavigationMixin(LightningElement) {
    
    @track loading = false;
    @track errorText = '';
    @track isLoggedIn = false;

    // Background Style
    get backgroundStyle() {
        return `background-image: url(${BGG_IMAGE});`;
    }

    connectedCallback() {
        const urlParams = new URLSearchParams(window.location.search);
        const authCode = urlParams.get('code');
        let accessToken = sessionStorage.getItem('provider_access_token');
        console.log('accessToken from session storage: ', accessToken);
        if (authCode && authCode != null) {
            console.log('authCode found in URL: ', authCode);
            this.handleOAuthCallback(authCode);
        }
        else if(accessToken && accessToken != null){
            this.loading = true;
            this.checkTokeValidityFromUI(accessToken)
        }
    }

    checkTokeValidityFromUI(token){
        checkTokenValidity({accessToken:token})
            .then(result => {
                console.log('tokenValidityResponse:', JSON.stringify(result));
                this.loading = false;
                if (result.isValid) {
                    this.isLoggedIn = true;
                    console.log('JIRA Cloud ID---',result?.resources[0]?.id);
                    sessionStorage.setItem('jira_cloud_id', result?.resources[0]?.id);
                    this.navigateToWorkitemSelection();
                } else if (result.errorMessage) {
                    console.error('Error validating access token: ', result.errorMessage);
                    sessionStorage.removeItem('provider_access_token'); // Clear invalid token
                }
            })
            .catch(error => {
                this.loading = false;
                console.error('Error validating access token: ', error);
            });
    }

    handleJiraLogin() {
        this.loading = true;
        const clientId = 'wTCk7CcKzhvLGgwXA7qOq5CovQcGXkKo'; 
        // Ensure this URI matches exactly where this component lives
        const redirectUri = 'https://pr1733992221355--poc.sandbox.my.site.com/resolutionOnDemand/s/get-started';
        const audience = 'api.atlassian.com';
        const scope = 'read:jira-work read:sprint:jira-software read:project:jira read:project.component:jira read:jira-user read:application-role:jira read:group:jira read:user:jira read:avatar:jira read:board-scope:jira-software';
        const state = Math.random().toString(36).substring(2);

        const authorizationUrl = `https://auth.atlassian.com/authorize?audience=${audience}&client_id=${clientId}&scope=${encodeURIComponent(scope)}&redirect_uri=${encodeURIComponent(redirectUri)}&state=${encodeURIComponent(state)}&response_type=code&prompt=consent`;

        // Redirect user to the authorization URL
        window.location.href = authorizationUrl;
    }

    handleOAuthCallback(authCode) {
        try {
            console.log('OAuth callback processing...');
            this.loading = true;
            
            exchangeAuthorizationCode({ code: authCode })
                .then(result => {
                    console.log('Auth Result: ', JSON.stringify(result));
                    sessionStorage.setItem('provider_access_token', String(result?.access_token));
                    this.isLoggedIn = true;
                    this.loading = false;
                    this.checkTokeValidityFromUI(result?.access_token);
                })
                .catch(error => {
                    console.error('Auth Error: ', JSON.stringify(error));
                    this.errorText = error.body ? error.body.message : error.message;
                    this.loading = false;
                    this.showToast('Login Failed', this.errorText, 'error');
                });
        } catch (error) {
            console.error('Exception in callback: ', error);
            this.errorText = error.message || JSON.stringify(error);
            this.loading = false;
            this.showToast('Exception', String(error), 'error');
        }
    }

    handleAzureDevopsLogin() {
        this.showToast('Info', 'Azure DevOps login not implemented yet.', 'info');
    }

    handleNotionLogin() {
        this.showToast('Info', 'Notion login not implemented yet.', 'info');
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }

    navigateToWorkitemSelection() {
        setTimeout(() => {
             this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'Workitem_selection__c' // The development name of the community page
                }
            });
        }, 3000);
    }
}