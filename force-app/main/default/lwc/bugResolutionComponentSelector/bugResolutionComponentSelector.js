// import { LightningElement, track } from 'lwc';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// import BACKGROUND_IMG from '@salesforce/resourceUrl/bggg';

// // --- APEX IMPORTS ---
// import getTypeAheadResults from '@salesforce/apex/TypeaheadSelectionController.getTypeAheadResults';
// import getMetadataTypes from '@salesforce/apex/TypeaheadSelectionController.getMetadataTypes';
// // 🟣 STEP 1: Import the new Apex methods for agent interaction
// import processComponentSelection from '@salesforce/apex/TypeaheadSelectionController.processComponentSelection';
// import removeComponentFromConversation from '@salesforce/apex/TypeaheadSelectionController.removeComponentFromConversation';


// export default class BugResolutionComponentSelector extends LightningElement {

//     // 🟣 Session ID to maintain conversation context with the agent
//     @track sessionId = null;

//     @track showTypeSpinner = true;

//     // This list should match the `validPills` list in the Apex Controller
//     REAL_TYPES = [
//         'LWC',
//         'Flow',
//         'AuraDefinitionBundle',
//         'ApexClass',
//         'ApexTrigger'
//     ];

//     @track activeTab = 'manual';
//     @track allMetadataTypes = [];
//     @track selectedType = null;
//     @track selectedRecord = null;
//     @track searchedValue = '';
//     @track recordOptions = [];
//     @track showTypeAheadComponent = false;
//     @track showSpinner = false;
//     @track isDisabled = true;

//     @track typeAheadKey = 0;

//     @track componentSelections = {
//         LWC: [],
//         Flow: [],
//         AuraDefinitionBundle: [],
//         ApexClass: [],
//         ApexTrigger: []
//     };

//     // ---------------------------------------------
//     // LOAD METADATA TYPES (No changes)
//     // ---------------------------------------------
//     connectedCallback() {
//         this.loadMetadataTypes();
//     }

//     async loadMetadataTypes() {
//         try {
//             const types = await getMetadataTypes();
//             this.allMetadataTypes = types.map(t => ({ label: t, value: t }));
//         } catch (error) {
//             console.error('Metadata load error:', error);
//             this.showToast('Error', 'Failed to load metadata types.', 'error');
//         } finally {
//             this.showTypeSpinner = false;
//         }
//     }

//     // ---------------------------------------------
//     // UI HANDLERS (No changes)
//     // ---------------------------------------------
//     handleTabSwitch(event) {
//         this.activeTab = event.currentTarget.dataset.tab;
//     }

//     get manualTabClass() { return this.activeTab === 'manual' ? 'toggle-btn active' : 'toggle-btn'; }

//     handleTypeDropdownChange(event) {
//         this.selectedType = event.detail.value;
//         this.selectedRecord = null;
//         this.searchedValue = '';
//         this.recordOptions = [];
//         this.isDisabled = false;
//         this.showTypeAheadComponent = false;
//         this.typeAheadKey++;

//         setTimeout(() => {
//             // Note: Your REAL_TYPES list has 'LWC' but the dropdown might have 'LightningComponentBundle'.
//             // This logic assumes they are aligned. I've updated REAL_TYPES to match your Apex for consistency.
//             this.showTypeAheadComponent = this.REAL_TYPES.includes(this.selectedType);
//         }, 0);
//     }

//     handleRecordChange(event) {
//         this.searchedValue = event.detail.inputValue;
//         this.showSpinner = true;
//         this.loadTypeaheadResults();
//     }
    
//     async loadTypeaheadResults() {
//         if (!this.selectedType || !this.searchedValue) {
//             this.recordOptions = [];
//             this.showSpinner = false;
//             return;
//         }

//         try {
//             const data = await getTypeAheadResults({
//                 searchedValue: this.searchedValue,
//                 selectedPill: this.selectedType
//             });

//             this.recordOptions = (Array.isArray(data) ? data : []).map(d => ({
//                 label: d.Name,
//                 value: d.Id,
//                 lastModifiedDate: d.LastModifiedDate
//             }));

//         } catch (error) {
//             console.error('Typeahead error:', error);
//             this.showToast('Error', 'Could not fetch component results.', 'error');
//         } finally {
//             this.showSpinner = false;
//         }
//     }

//     handleSelectEvent(event) {
//         const id = event.detail.value;
//         this.selectedRecord = this.recordOptions.find(r => r.value === id) || null;
//     }

//     handleRemoveEvent() {
//         this.selectedRecord = null;
//         this.isDisabled = true;
//     }

//     get isAddDisabled() {
//         return !(this.selectedType && this.selectedRecord);
//     }

//     // ---------------------------------------------
//     // 🟣 STEP 2: MODIFY ADD COMPONENT TO CALL AGENT
//     // ---------------------------------------------
//     async handleAddClick() {
//         if (!this.selectedType || !this.selectedRecord) {
//             this.showToast('Warning', 'Please select a component', 'warning');
//             return;
//         }

//         const type = this.selectedType;
//         const name = this.selectedRecord.label;
//         const id = this.selectedRecord.value;

//         // Add pill to UI for immediate feedback
//         if (!this.componentSelections[type].some(item => item.name === name)) {
//             this.componentSelections[type] = [
//                 ...this.componentSelections[type],
//                 { name, id }
//             ];
//             this.componentSelections = { ...this.componentSelections };
//         }

//         // Reset the input controls
//         this.selectedRecord = null;
//         this.searchedValue = '';
//         this.isDisabled = true;

//         // --- AGENT CALL ---
//         this.showSpinner = true; // Show spinner during agent processing
//         try {
//             console.log('Session ID being sent to removeComponent: ', this.sessionId);
//             // Call the Apex method to send component details to the agent
//             const result = await processComponentSelection({
//                 componentType: type,
//                 componentName: name,
//                 componentId: id,
//                 sessionId: this.sessionId
//             });

//             // IMPORTANT: Store the returned sessionId to maintain conversation context
//             this.sessionId = result.sessionId;

//             // Display the agent's response in a toast message
//             this.showToast('Agent Response', result.value, 'success');
//             console.log('Agent Raw Response (Add):', result.rawResponse);

//         } catch (error) {
//             console.error('Error processing component with agent:', error);
//             this.showToast('Agent Error', 'An error occurred while communicating with the agent.', 'error');
//         } finally {
//             this.showSpinner = false; // Hide spinner
//         }
//     }

//     // ---------------------------------------------
//     // 🟣 STEP 3: MODIFY REMOVE PILL TO CALL AGENT
//     // ---------------------------------------------
//     async handleRemovePill(event) {
//         const type = event.currentTarget.dataset.type;
//         const name = event.currentTarget.dataset.name;
//         const id = event.currentTarget.dataset.id; // IMPORTANT: Assumes data-id is on the pill

//         // Remove from UI immediately for responsiveness
//         this.componentSelections[type] =
//             this.componentSelections[type].filter(item => item.name !== name);

//         this.componentSelections = { ...this.componentSelections };

//         // --- AGENT CALL ---
//         this.showSpinner = true;
//         try {
//             // Call Apex to tell the agent to forget this component
//             const result = await removeComponentFromConversation({
//                 componentType: type,
//                 componentName: name,
//                 componentId: id,
//                 sessionId: this.sessionId
//             });

//             // Update session ID and show confirmation
//             this.sessionId = result.sessionId;
//             this.showToast('Agent Confirmation', result.value, 'info');
//             console.log('Agent Raw Response (Remove):', result.rawResponse);

//         } catch (error) {
//             console.error('Error removing component from agent context:', error);
//             this.showToast('Agent Error', 'Failed to remove component from agent context.', 'error');
//         } finally {
//             this.showSpinner = false;
//         }
//     }

//     // ---------------------------------------------
//     // GROUPING & HELPERS (No major changes)
//     // ---------------------------------------------
//     get groupedSelections() {
//         return Object.keys(this.componentSelections).map(type => ({
//             type,
//             label: type,
//             items: this.componentSelections[type].map(item => ({
//                 name: item.name,
//                 id: item.id, // This `id` is crucial for the remove handler
//                 type,
//                 uniqueKey: `${type}_${item.name}`
//             }))
//         })).filter(group => group.items.length > 0);
//     }

//     get hasAnySelection() {
//         return Object.values(this.componentSelections).some(list => list.length > 0);
//     }

//     showToast(title, message, variant) {
//         this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
//     }

//     get backgroundStyle() {
//         return `background-image: url(${BACKGROUND_IMG});
//                 background-size: cover;
//                 background-position: center;
//                 background-repeat: no-repeat;
//                 min-height: 600px;`;
//     }
// }



import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import BACKGROUND_IMG from '@salesforce/resourceUrl/bggg';

// --- APEX IMPORTS ---
import getTypeAheadResults from '@salesforce/apex/TypeaheadSelectionController.getTypeAheadResults';
import getMetadataTypes from '@salesforce/apex/TypeaheadSelectionController.getMetadataTypes';
import processComponentSelection from '@salesforce/apex/TypeaheadSelectionController.processComponentSelection';
import removeComponentFromConversation from '@salesforce/apex/TypeaheadSelectionController.removeComponentFromConversation';


export default class BugResolutionComponentSelector extends LightningElement {

    // Tracked property to hold the agent's session ID across interactions
    @track sessionId = null;

    @track showTypeSpinner = true;

    // List of types that use the custom typeahead component
    REAL_TYPES = [
        'LWC',
        'Flow',
        'AuraDefinitionBundle',
        'ApexClass',
        'ApexTrigger'
    ];

    // UI State Properties
    @track activeTab = 'manual';
    @track allMetadataTypes = [];
    @track selectedType = null;
    @track selectedRecord = null;
    @track searchedValue = '';
    @track recordOptions = [];
    @track showTypeAheadComponent = false;
    @track showSpinner = false;
    @track isDisabled = true;
    @track typeAheadKey = 0;

    // Data structure to hold the user's selections
    @track componentSelections = {
        LWC: [],
        Flow: [],
        AuraDefinitionBundle: [],
        ApexClass: [],
        ApexTrigger: []
    };

    // ---------------------------------------------
    // INITIALIZATION
    // ---------------------------------------------
    connectedCallback() {
        this.loadMetadataTypes();
    }

    async loadMetadataTypes() {
        try {
            const types = await getMetadataTypes();
            this.allMetadataTypes = types.map(t => ({ label: t, value: t }));
        } catch (error) {
            console.error('Metadata load error:', error);
            this.showToast('Error', 'Failed to load metadata types.', 'error');
        } finally {
            this.showTypeSpinner = false;
        }
    }

    // ---------------------------------------------
    // UI EVENT HANDLERS
    // ---------------------------------------------
    handleTabSwitch(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    get manualTabClass() { return this.activeTab === 'manual' ? 'toggle-btn active' : 'toggle-btn'; }

    handleTypeDropdownChange(event) {
        this.selectedType = event.detail.value;
        this.selectedRecord = null;
        this.searchedValue = '';
        this.recordOptions = [];
        this.isDisabled = false;
        this.showTypeAheadComponent = false;
        this.typeAheadKey++; // Force-resets the child typeahead component

        setTimeout(() => {
            this.showTypeAheadComponent = this.REAL_TYPES.includes(this.selectedType);
        }, 0);
    }

    handleRecordChange(event) {
        this.searchedValue = event.detail.inputValue;
        this.showSpinner = true;
        this.loadTypeaheadResults();
    }
    
    async loadTypeaheadResults() {
        if (!this.selectedType || !this.searchedValue) {
            this.recordOptions = [];
            this.showSpinner = false;
            return;
        }

        try {
            const data = await getTypeAheadResults({
                searchedValue: this.searchedValue,
                selectedPill: this.selectedType
            });
            this.recordOptions = (Array.isArray(data) ? data : []).map(d => ({
                label: d.Name,
                value: d.Id,
                lastModifiedDate: d.LastModifiedDate
            }));
        } catch (error) {
            console.error('Typeahead error:', error);
            this.showToast('Error', 'Could not fetch component results.', 'error');
        } finally {
            this.showSpinner = false;
        }
    }

    handleSelectEvent(event) {
        const id = event.detail.value;
        this.selectedRecord = this.recordOptions.find(r => r.value === id) || null;
    }

    handleRemoveEvent() {
        this.selectedRecord = null;
        this.isDisabled = true;
    }

    get isAddDisabled() {
        return !(this.selectedType && this.selectedRecord);
    }

    // ---------------------------------------------
    // ADD COMPONENT & CALL AGENT (Corrected Logic)
    // ---------------------------------------------
    async handleAddClick() {
        if (!this.selectedType || !this.selectedRecord) {
            this.showToast('Warning', 'Please select a component', 'warning');
            return;
        }

        const type = this.selectedType;
        const name = this.selectedRecord.label;
        const id = this.selectedRecord.value;

        if (this.componentSelections[type].some(item => item.name === name)) {
            this.showToast('Info', 'Component already added.', 'info');
            return;
        }

        this.showSpinner = true;
        try {
            // STEP 1: Call the agent FIRST to get a successful response and sessionId.
            const result = await processComponentSelection({
                componentType: type,
                componentName: name,
                componentId: id,
                sessionId: this.sessionId
            });

            // STEP 2: The call was successful. NOW, update the component's state.
            this.sessionId = result.sessionId; // This is crucial for session continuity.

            // STEP 3: Update the UI to show the new pill. This triggers the re-render.
            this.componentSelections[type] = [
                ...this.componentSelections[type],
                { name, id }
            ];
            this.componentSelections = { ...this.componentSelections };

            // STEP 4: Reset the input controls.
            this.selectedRecord = null;
            this.searchedValue = '';
            this.isDisabled = true;

            // STEP 5: Show the success message from the agent.
            this.showToast('Agent Response', result.value, 'success');

        } catch (error) {
            console.error('Error processing component with agent:', error);
            this.showToast('Agent Error', 'An error occurred while communicating with the agent.', 'error');
        } finally {
            this.showSpinner = false;
        }
    }

    // ---------------------------------------------
    // REMOVE PILL & CALL AGENT (Corrected Logic)
    // ---------------------------------------------
    async handleRemovePill(event) {
        const type = event.currentTarget.dataset.type;
        const name = event.currentTarget.dataset.name;
        const id = event.currentTarget.dataset.id; 

        this.showSpinner = true;
        try {
            // STEP 1: Call the agent FIRST, passing the stored sessionId.
            const result = await removeComponentFromConversation({
                componentType: type,
                componentName: name,
                componentId: id,
                sessionId: this.sessionId
            });

            // STEP 2: The call was successful. NOW, update the component's state.
            this.sessionId = result.sessionId; // Maintain the session continuity.

            // STEP 3: Update the UI to remove the pill.
            this.componentSelections[type] =
                this.componentSelections[type].filter(item => item.name !== name);
            this.componentSelections = { ...this.componentSelections };

            // STEP 4: Show the confirmation message from the agent.
            this.showToast('Agent Confirmation', result.value, 'info');

        } catch (error) {
            console.error('Error removing component from agent context:', error);
            this.showToast('Agent Error', 'Failed to remove component from agent context.', 'error');
            // If the call fails, the pill correctly remains in the UI.
        } finally {
            this.showSpinner = false;
        }
    }

    // ---------------------------------------------
    // GETTERS & UTILITY FUNCTIONS
    // ---------------------------------------------
    get groupedSelections() {
        return Object.keys(this.componentSelections).map(type => ({
            type,
            label: type,
            items: this.componentSelections[type].map(item => ({
                name: item.name,
                id: item.id,
                type,
                uniqueKey: `${type}_${item.name}`
            }))
        })).filter(group => group.items.length > 0);
    }

    get hasAnySelection() {
        return Object.values(this.componentSelections).some(list => list.length > 0);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get backgroundStyle() {
        return `background-image: url(${BACKGROUND_IMG});
                background-size: cover;
                background-position: center;
                background-repeat: no-repeat;
                min-height: 600px;`;
    }
}