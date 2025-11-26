import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import BACKGROUND_IMG from '@salesforce/resourceUrl/bggg';

import getTypeAheadResults from '@salesforce/apex/TypeaheadSelectionController.getTypeAheadResults';
import getMetadataTypes from '@salesforce/apex/TypeaheadSelectionController.getMetadataTypes';

export default class BugResolutionComponentSelector extends LightningElement {

    sessionId = null;

    @track showTypeSpinner = true;

    REAL_TYPES = [
        'LightningComponentBundle',
        'Flow',
        'AuraDefinitionBundle',
        'ApexClass',
        'ApexTrigger'
    ];

    @track activeTab = 'manual';
    @track allMetadataTypes = [];
    @track selectedType = null;
    @track selectedRecord = null;
    @track searchedValue = '';
    @track recordOptions = [];
    @track showTypeAheadComponent = false;
    @track showSpinner = false;
    @track isDisabled = true;

    // 🔥 NEW — used to force-reset the child component
    @track typeAheadKey = 0;

    @track componentSelections = {
        LightningComponentBundle: [],
        Flow: [],
        AuraDefinitionBundle: [],
        ApexClass: [],
        ApexTrigger: []
    };

    // ---------------------------------------------
    // LOAD METADATA TYPES
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
        } finally {
            this.showTypeSpinner = false;
        }
    }

    // ---------------------------------------------
    // TAB SWITCH
    // ---------------------------------------------
    handleTabSwitch(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    get manualTabClass() { return this.activeTab === 'manual' ? 'toggle-btn active' : 'toggle-btn'; }

    // ---------------------------------------------
    // TYPE DROPDOWN CHANGE
    // ---------------------------------------------
    handleTypeDropdownChange(event) {
        this.selectedType = event.detail.value;

        this.selectedRecord = null;
        this.searchedValue = '';
        this.recordOptions = [];
        this.isDisabled = false;

        // 🔥 Reset: Hide → Change Key → Show (fresh component)
        this.showTypeAheadComponent = false;
        this.typeAheadKey++;

        setTimeout(() => {
            this.showTypeAheadComponent = this.REAL_TYPES.includes(this.selectedType);
        }, 0);
    }

    // ---------------------------------------------
    // TYPEAHEAD INPUT HANDLER
    // ---------------------------------------------
    handleRecordChange(event) {
        this.searchedValue = event.detail.inputValue;
        this.showSpinner = true;
        this.loadTypeaheadResults();
    }

    // ---------------------------------------------
    // FETCH TYPEAHEAD RESULTS
    // ---------------------------------------------
    async loadTypeaheadResults() {
        if (!this.selectedType) {
            this.showSpinner = false;
            return;
        }
        console.log('Selected pill->', this.selectedType);
        console.log('searchedValue->', this.searchedValue);
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
        } finally {
            this.showSpinner = false;
        }
    }

    // ---------------------------------------------
    // SELECT EVENT
    // ---------------------------------------------
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
    // ADD COMPONENT
    // ---------------------------------------------
    handleAddClick() {
        if (!this.selectedType || !this.selectedRecord) {
            this.showToast('Warning', 'Please select a component', 'warning');
            return;
        }

        const name = this.selectedRecord.label;
        const id = this.selectedRecord.value;

        if (!this.componentSelections[this.selectedType].some(item => item.name === name)) {
            this.componentSelections[this.selectedType] = [
                ...this.componentSelections[this.selectedType],
                { name, id }
            ];
            this.componentSelections = { ...this.componentSelections };
        }

        this.selectedRecord = null;
        this.searchedValue = '';
        this.isDisabled = true;
    }

    // ---------------------------------------------
    // REMOVE PILL
    // ---------------------------------------------
    handleRemovePill(event) {
        const type = event.currentTarget.dataset.type;
        const name = event.currentTarget.dataset.name;

        this.componentSelections[type] =
            this.componentSelections[type].filter(item => item.name !== name);

        this.componentSelections = { ...this.componentSelections };
    }

    // ---------------------------------------------
    // GROUPING
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

    // ---------------------------------------------
    // BACKGROUND IMAGE
    // ---------------------------------------------
    get backgroundStyle() {
        return `background-image: url(${BACKGROUND_IMG});
                background-size: cover;
                background-position: center;
                background-repeat: no-repeat;
                min-height: 600px;`;
    }
}