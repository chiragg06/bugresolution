import { LightningElement, track } from 'lwc';
import uploadProfileImage from '@salesforce/apex/ProfileImageUploadController.uploadProfileImage';

export default class ProfileImageUpload extends LightningElement {

    @track fileName;
    @track fileData;
    @track errorMessage;

    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        this.fileName = file.name;

        const reader = new FileReader();
        reader.onload = () => {
            this.fileData = reader.result.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    handleUpload() {
        this.errorMessage = null;

        uploadProfileImage({
            fileName: this.fileName,
            base64Data: this.fileData
        })
        .then(() => {
            // This will never execute (simulated failure)
        })
        .catch(error => {
            this.errorMessage =
                error?.body?.message || 'Image upload failed.';
        });
    }
}