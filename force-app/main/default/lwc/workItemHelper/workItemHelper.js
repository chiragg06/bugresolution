import { LightningElement, track, wire } from 'lwc';
import getUserDetails from '@salesforce/apex/DemoJIRASyncController.getUserDetails';
import getProjects from '@salesforce/apex/DemoJIRASyncController.getProjects';
import getBoards from '@salesforce/apex/DemoJIRASyncController.getBoards';
import getSprints from '@salesforce/apex/DemoJIRASyncController.getSprints';
import getBugsForSprint from '@salesforce/apex/DemoJIRASyncController.getBugsForSprint';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';


// Import the same background used in Login
import BGG_IMAGE from '@salesforce/resourceUrl/bgg';

export default class WorkItemHelper extends NavigationMixin(LightningElement) {
    @track userName;
    @track userAvatar;
    @track projects = []; 
    @track boards = []; 
    @track sprints = []; 
    @track bugs = []; 
    @track selectedProject = '';
    @track selectedBoard = '';
    @track selectedSprint = '';
    @track selectedBugId = '';
    @track isLoading = false;

    // Getter for the background image
    get backgroundStyle() {
        return `background-image: url(${BGG_IMAGE});`;
    }

    get nextDisabled(){
        return !this.selectedBugId;
    }

    connectedCallback() {
        const accessToken = sessionStorage.getItem('provider_access_token');
        const jiraCloudId = sessionStorage.getItem('jira_cloud_id');

        if (accessToken && jiraCloudId) {
            this.fetchUserDetails(accessToken, jiraCloudId);
            this.fetchProjects(accessToken, jiraCloudId);
        }
    }

    async fetchUserDetails(accessToken, jiraCloudId) {
        try {
            const userDetails = await getUserDetails({ accessToken: accessToken, jiraCloudId: jiraCloudId });
            this.userName = userDetails.displayName;
            this.userAvatar = userDetails.avatarUrls['24x24'];
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    async fetchProjects(accessToken, jiraCloudId) {
        try {
            this.isLoading = true;
            const projectsResponse = await getProjects({ accessToken: accessToken, jiraCloudId: jiraCloudId });
            this.projects = projectsResponse.map(project => ({
                label: project.name,  
                value: String(project.id)    
            }));
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async fetchBoards(accessToken, jiraCloudId) {
        try {
            this.isLoading = true;
            const boardsResponse = await getBoards({ accessToken: accessToken, projectKeyOrId: this.selectedProject, jiraCloudId: jiraCloudId });
            this.boards = boardsResponse?.values?.map(board => ({
                label: board.name,   
                value: String(board.id)      
            }));
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async fetchSprints(accessToken, jiraCloudId) {
        try {
            this.isLoading = true;
            const sprintsResponse = await getSprints({ accessToken: accessToken, boardId: this.selectedBoard, jiraCloudId: jiraCloudId });
            this.sprints = sprintsResponse?.values?.map(sprint => ({
                label: sprint.name,  
                value: String(sprint.id)    
            }));
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async fetchBugs(accessToken, jiraCloudId) {
        try {
            this.isLoading = true;
            const bugsResponse = await getBugsForSprint({ accessToken: accessToken, sprintId: this.selectedSprint, jiraCloudId: jiraCloudId });

            this.bugs = bugsResponse?.issues?.map(bug => ({
                label: bug.key,  
                value: bug.id              
            }));
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleProjectChange(event) {
        this.selectedProject = event.target.value;
        this.selectedBoard = '';
        this.selectedSprint = '';
        this.bugs = [];
        this.fetchBoards(sessionStorage.getItem('provider_access_token'), sessionStorage.getItem('jira_cloud_id'));
    }

    handleBoardChange(event) {
        this.selectedBoard = event.detail.value;
        console.log('selectedBoard: '+this.selectedBoard, 'this.boards', JSON.stringify(this.boards));
        this.selectedSprint = '';
        this.bugs = [];
        this.fetchSprints(sessionStorage.getItem('provider_access_token'), sessionStorage.getItem('jira_cloud_id'));
        console.log('selectedBoard: '+this.selectedBoard, 'this.boards', JSON.stringify(this.boards));
    }

    handleSprintChange(event) {
        this.selectedSprint = event.detail.value;
        this.fetchBugs(sessionStorage.getItem('provider_access_token'), sessionStorage.getItem('jira_cloud_id'));
    }

    handleBugChange(event) {
        this.selectedBugId = event.detail.value;
    }

    handleNext() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'component__c'
            },
            state: {
                bugId: this.selectedBugId
            }
        });
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}