public without sharing class ProfileImageUploadController {

    @AuraEnabled
    public static void uploadProfileImage(String fileName, String base64Data) {

        // Simulate backend validation
        if (String.isBlank(fileName) || String.isBlank(base64Data)) {
            throw new AuraHandledException('Invalid image file.');
        }


        throw new AuraHandledException(
            'Profile image upload failed due to server error.'
        );
    }
}