import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LumoChat';

  @override
  String get navChats => 'Messages';

  @override
  String get navGroups => 'Groups';

  @override
  String get navContacts => 'Contacts';

  @override
  String get navProfile => 'Profile';

  @override
  String get commonUnexpectedError => 'Something went wrong';

  @override
  String get commonErrorNetwork => 'Network error. Please try again.';

  @override
  String get commonErrorPermissionDenied => 'You do not have permission to perform this action.';

  @override
  String get commonErrorServiceUnavailable => 'Service is temporarily unavailable. Please try again later.';

  @override
  String get commonErrorTimeout => 'The request timed out. Please try again.';

  @override
  String get commonErrorUnauthenticated => 'Your session has expired. Please sign in again.';

  @override
  String get commonErrorInvalidInput => 'Invalid input. Please review and try again.';

  @override
  String get commonErrorConflict => 'This action conflicts with current data.';

  @override
  String get commonErrorNotFound => 'Requested data was not found.';

  @override
  String get commonNoSearchResults => 'No results found';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonAddFriend => 'Add friend';

  @override
  String get commonClose => 'Close';

  @override
  String get commonOnline => 'Online';

  @override
  String get commonOffline => 'Offline';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonPin => 'Pin';

  @override
  String get commonUnpin => 'Unpin';

  @override
  String get commonHide => 'Hide';

  @override
  String get commonLeave => 'Leave';

  @override
  String get commonSave => 'Save';

  @override
  String get commonLoading => 'Processing...';

  @override
  String get commonMore => 'More';

  @override
  String get chatListSearchHint => 'Search conversations...';

  @override
  String get chatListNoFriendsPrompt => 'You have no friends yet. Add friends in the Contacts tab.';

  @override
  String get chatListNoConversations => 'No conversations yet';

  @override
  String get chatListYourStory => 'Your story';

  @override
  String get storyActionViewMyStory => 'View my story';

  @override
  String get storyActionAddStory => 'Add new story';

  @override
  String get storyComposeTitle => 'Create story';

  @override
  String get storyCaptionHint => 'Write a caption...';

  @override
  String get storyVisibilityLabel => 'Visibility';

  @override
  String get storyVisibilityFriends => 'Friends only';

  @override
  String get storyVisibilityPublic => 'Public';

  @override
  String get storyPublishAction => 'Post';

  @override
  String get storyPublishSuccess => 'Story posted';

  @override
  String storyPublishFailed(String error) {
    return 'Unable to post story: $error';
  }

  @override
  String get storySourcePhotoGallery => 'Photo from gallery';

  @override
  String get storySourcePhotoCamera => 'Photo from camera';

  @override
  String get storySourceVideoGallery => 'Video from gallery';

  @override
  String get storySourceVideoCamera => 'Video from camera';

  @override
  String get storyViewerVideoFallback => 'Video story';

  @override
  String get storyViewerNow => 'now';

  @override
  String get storyAudienceTitle => 'Story viewers';

  @override
  String storyAudienceCount(String count) {
    return '$count views';
  }

  @override
  String get storyAudienceEmpty => 'No one has viewed this story yet';

  @override
  String get storyAudienceNoReaction => 'No reaction';

  @override
  String get storyDeleteTitle => 'Delete story?';

  @override
  String get storyDeleteConfirm => 'This story will be removed immediately.';

  @override
  String get storyDeleteSuccess => 'Story deleted';

  @override
  String get storyDeleteFailed => 'Unable to delete story';

  @override
  String get storyEditorTitle => 'Edit story';

  @override
  String get storyEditorResetZoom => 'Reset zoom';

  @override
  String get storyEditorTextHint => 'Add text on your story...';

  @override
  String get storyEditorTextDragHint => 'Drag text directly on photo to reposition';

  @override
  String get storyEditorTextSizeLabel => 'Text size';

  @override
  String get storyEditorTextColorLabel => 'Text color';

  @override
  String get storyEditorTextBold => 'Bold text';

  @override
  String get storyEditorUsePhoto => 'Use this photo';

  @override
  String get storyEditorExportFailed => 'Could not apply edits. Please try again.';

  @override
  String get storyMusicTrackLabel => 'Music';

  @override
  String get storyMusicNone => 'No music';

  @override
  String storyMusicStartLabel(String time) {
    return 'Start at $time';
  }

  @override
  String storyMusicVolumeLabel(String percent) {
    return 'Volume $percent';
  }

  @override
  String storyMusicPlayingLabel(String track) {
    return 'Music: $track';
  }

  @override
  String get chatListTapToStart => 'Tap to start chatting';

  @override
  String get chatListTyping => 'typing...';

  @override
  String get chatSearchHint => 'Search in conversation...';

  @override
  String get chatSearchNoMatches => 'No matching messages';

  @override
  String get chatInputHint => 'Type a message...';

  @override
  String get chatReplyingTo => 'Replying';

  @override
  String get chatImagePlaceholder => '📷 [image]';

  @override
  String get chatMessageDeleted => 'Message unavailable';

  @override
  String get chatMessageRecalled => 'Message recalled';

  @override
  String get chatStatusSent => 'Sent';

  @override
  String get chatStatusDelivered => 'Delivered';

  @override
  String get chatStatusRead => 'Read';

  @override
  String get chatUploadingImage => 'Uploading image...';

  @override
  String get chatImageUploadFailed => 'Image upload failed';

  @override
  String chatImageUploadFailedWithReason(String error) {
    return 'Image upload failed: $error';
  }

  @override
  String get chatRetry => 'Retry';

  @override
  String chatSendFailed(String error) {
    return 'Send failed: $error';
  }

  @override
  String chatImagePickFailed(String error) {
    return 'Unable to pick image: $error';
  }

  @override
  String get chatContextReply => 'Reply';

  @override
  String get chatContextCopy => 'Copy';

  @override
  String get chatContextPinMessage => 'Pin message';

  @override
  String get chatContextUnpinMessage => 'Unpin message';

  @override
  String get chatPinnedMessageTitle => 'Pinned message';

  @override
  String get chatCopied => 'Copied';

  @override
  String get chatRecallForMe => 'Recall for me';

  @override
  String get chatRecalledForMeSuccess => 'Message recalled for you';

  @override
  String get chatRecallForEveryone => 'Recall for everyone';

  @override
  String get chatRecalledForEveryoneSuccess => 'Message recalled for everyone';

  @override
  String get chatMessagePinnedSuccess => 'Message pinned';

  @override
  String get chatMessageUnpinnedSuccess => 'Message unpinned';

  @override
  String chatPinnedActionFailed(String error) {
    return 'Pinned message action failed: $error';
  }

  @override
  String get chatListPinSuccess => 'Chat has been pinned';

  @override
  String get chatListUnpinSuccess => 'Chat has been unpinned';

  @override
  String get chatListHideSuccess => 'Chat has been hidden';

  @override
  String get chatListDeleteSuccess => 'Chat removed from your list';

  @override
  String chatListActionFailed(String error) {
    return 'Chat action failed: $error';
  }

  @override
  String contactsActionFailed(String error) {
    return 'Action failed: $error';
  }

  @override
  String get contactsLoadProfileError => 'Failed to load profile';

  @override
  String get contactsLoadContactsError => 'Failed to load contacts';

  @override
  String get contactsSearchHint => 'Search friends...';

  @override
  String get contactsFilterAll => 'All';

  @override
  String get contactsFilterRequests => 'Requests';

  @override
  String get contactsFilterFriends => 'Friends';

  @override
  String get contactsFilterDiscover => 'Discover';

  @override
  String get contactsQuickInvites => 'Invites';

  @override
  String get contactsQuickSent => 'Sent';

  @override
  String get contactsQuickFriends => 'Friends';

  @override
  String contactsOnlineFriends(int count) {
    return 'Friends online ($count)';
  }

  @override
  String get contactsSectionFriendRequests => 'Friend requests';

  @override
  String get contactsRejectedInvite => 'Invitation declined';

  @override
  String get contactsAcceptedFriend => 'Friend request accepted';

  @override
  String get contactsSectionSent => 'Sent invitations';

  @override
  String get contactsPendingResponse => 'Waiting for response';

  @override
  String get contactsCanceledInvite => 'Invitation canceled';

  @override
  String get contactsSectionFriends => 'Friends';

  @override
  String get contactsUnfriended => 'Removed from friends';

  @override
  String get contactsSectionDiscover => 'Discover';

  @override
  String get contactsSentInvite => 'Friend request sent';

  @override
  String get contactsNoMatchingData => 'No matching data';

  @override
  String get contactsEmptyNoUsers => 'No users available to display.';

  @override
  String get contactsEmptyRequests => 'No friend requests right now.';

  @override
  String get contactsEmptyFriends => 'You have no friends yet.';

  @override
  String get contactsEmptyDiscover => 'No friend suggestions available.';

  @override
  String get contactsStatusActive => 'Active now';

  @override
  String get contactsStatusOffline => 'Offline';

  @override
  String get groupsTitle => 'Group chats';

  @override
  String get groupsSearchHint => 'Search groups by name or message...';

  @override
  String get groupsSortRecent => 'Recent';

  @override
  String get groupsSortName => 'Name';

  @override
  String get groupsSortMembers => 'Members';

  @override
  String groupsLoadError(String error) {
    return 'Error loading groups: $error';
  }

  @override
  String get groupsEmpty => 'You have not joined any group yet';

  @override
  String get groupsNoSearchResults => 'No groups found for this search';

  @override
  String get groupsUnnamed => 'Unnamed group';

  @override
  String get groupsNoMessagesYet => 'No messages yet';

  @override
  String groupsMemberCount(int count) {
    return '$count members';
  }

  @override
  String get groupsActionAddMembers => 'Add members';

  @override
  String get groupsActionLeaveGroup => 'Leave group';

  @override
  String get groupsActionDeleteGroup => 'Delete group';

  @override
  String groupsActionFailed(String error) {
    return 'Group action failed: $error';
  }

  @override
  String get groupsPinSuccess => 'Group chat pinned';

  @override
  String get groupsUnpinSuccess => 'Group chat unpinned';

  @override
  String get groupsAddMembersDialogTitle => 'Add members to group';

  @override
  String get groupsAddMembersSearchHint => 'Search members...';

  @override
  String get groupsAddMembersNoFriends => 'You have no friends to add into this group';

  @override
  String get groupsAddMembersNoCandidates => 'No suitable friends left to add';

  @override
  String groupsAddMembersSuccess(int count) {
    return 'Added $count members';
  }

  @override
  String get groupsLeaveConfirmTitle => 'Confirm leaving group';

  @override
  String groupsLeaveConfirmMessage(String groupName) {
    return 'Are you sure you want to leave \"$groupName\"?';
  }

  @override
  String get groupsLeaveSuccess => 'You left the group';

  @override
  String get groupsDeleteConfirmTitle => 'Confirm deleting group';

  @override
  String groupsDeleteConfirmMessage(String groupName) {
    return 'Are you sure you want to delete \"$groupName\"? This action cannot be undone.';
  }

  @override
  String get groupsDeleteNotAllowed => 'You do not have permission to delete this group';

  @override
  String get groupsDeleteSuccess => 'Group deleted';

  @override
  String get groupsCreateTitle => 'Create new group';

  @override
  String get groupsCreateAction => 'Create';

  @override
  String get groupsCreateDefaultName => 'New group';

  @override
  String get groupsCreateNameHint => 'Group name (optional)';

  @override
  String get groupsCreateDescriptionHint => 'Group description (optional)';

  @override
  String groupsCreateSelectedCount(int count) {
    return 'Selected ($count)';
  }

  @override
  String get groupsCreateSearchHint => 'Search friends to add...';

  @override
  String get groupsCreateNoFriends => 'You have no friends to add into a group.';

  @override
  String groupsCreateButton(int count) {
    return 'Create group with $count members';
  }

  @override
  String get groupsCreateInProgress => 'Creating group...';

  @override
  String groupsCreateFailed(String error) {
    return 'Create group failed: $error';
  }

  @override
  String get groupsCreateLoadProfileError => 'Unable to load your profile.';

  @override
  String get groupsCreateLoadFriendsError => 'Unable to load your friends list.';

  @override
  String get authValidationRequiredFields => 'Please fill in all required fields.';

  @override
  String get authValidationNameRequired => 'Please enter your name.';

  @override
  String get authValidationPasswordMismatch => 'Password confirmation does not match.';

  @override
  String get authValidationPhoneRequired => 'Please enter your phone number.';

  @override
  String get authValidationOtpRequired => 'Please enter a valid OTP code.';

  @override
  String get authErrorInvalidCredentials => 'Invalid login credentials.';

  @override
  String get authErrorEmailAlreadyInUse => 'This email is already in use.';

  @override
  String get authErrorWeakPassword => 'Password is too weak. Please choose a stronger one.';

  @override
  String get authErrorTooManyRequests => 'Too many requests. Please try again later.';

  @override
  String get authErrorInvalidOtp => 'OTP is invalid or has expired.';

  @override
  String get authErrorInvalidPhoneNumber => 'Phone number is invalid.';

  @override
  String get authErrorSmsQuotaExceeded => 'SMS quota reached for today. Please try again later.';

  @override
  String get authErrorBillingNotEnabled => 'Firebase Billing is not enabled for real SMS verification.';

  @override
  String get authErrorOperationNotAllowed => 'This sign-in method is not enabled.';

  @override
  String authErrorAutoVerificationFailed(String error) {
    return 'Auto verification failed: $error';
  }

  @override
  String authErrorVerificationFailed(String error) {
    return 'Verification failed: $error';
  }

  @override
  String authErrorSendOtpFailed(String error) {
    return 'Failed to send OTP: $error';
  }

  @override
  String authErrorGoogleFailed(String error) {
    return 'Google sign-in failed: $error';
  }

  @override
  String get authAppleComingSoon => 'Apple sign-in is coming soon.';

  @override
  String get profileNotUpdated => 'Not updated';

  @override
  String get profileLoadError => 'Unable to load profile';

  @override
  String get profileFallbackUser => 'User';

  @override
  String get profileFallbackBio => 'Using LumoChat';

  @override
  String get profileSummaryTitle => 'LumoChat Profile';

  @override
  String get profileSummaryName => 'Name';

  @override
  String get profileSummaryEmail => 'Email';

  @override
  String get profileSummaryPhone => 'Phone';

  @override
  String get profileSummaryAddress => 'Address';

  @override
  String get profileSummaryCity => 'City';

  @override
  String get profileSummaryGender => 'Gender';

  @override
  String get profileSummaryBirthDate => 'Birth date';

  @override
  String get profileSummaryOccupation => 'Occupation';

  @override
  String get profileSummaryWebsite => 'Website';

  @override
  String get profileCopySummarySuccess => 'Profile information copied';

  @override
  String get profileStatFriends => 'Friends';

  @override
  String get profileStatGroups => 'Groups';

  @override
  String get profileStatStatus => 'Status';

  @override
  String get profileEdit => 'Edit';

  @override
  String get profileShare => 'Share';

  @override
  String get profileSectionBasicInfo => 'Basic Information';

  @override
  String get profileFieldPhone => 'Phone';

  @override
  String get profileFieldAddress => 'Address';

  @override
  String get profileFieldCity => 'City';

  @override
  String get profileFieldGender => 'Gender';

  @override
  String get profileFieldBirthDate => 'Birth date';

  @override
  String get profileFieldOccupation => 'Occupation';

  @override
  String get profileFieldWebsite => 'Website';

  @override
  String get profileSectionAccount => 'Account';

  @override
  String get profileMenuPersonalInfo => 'Personal information';

  @override
  String get profileMenuCopyUserId => 'Copy user ID';

  @override
  String get profileCopyUserIdSuccess => 'User ID copied';

  @override
  String get profileMenuSecurity => 'Security';

  @override
  String get profileSecurityTitle => 'Security';

  @override
  String get profileSecurityMessage => 'Advanced security features will be available soon.';

  @override
  String get profileSectionCustomization => 'Customization';

  @override
  String get profileMenuDarkMode => 'Dark mode';

  @override
  String get profileMenuLanguage => 'Language';

  @override
  String get profileLanguageVietnamese => 'Vietnamese';

  @override
  String get profileLanguageEnglish => 'English';

  @override
  String get profileLanguageDialogTitle => 'Choose language';

  @override
  String profileLanguageSaveFailed(String error) {
    return 'Failed to save language setting: $error';
  }

  @override
  String get profileSectionSupport => 'Support';

  @override
  String get profileMenuHelpCenter => 'Help center';

  @override
  String get profileHelpTitle => 'Support';

  @override
  String get profileHelpMessage => 'Contact: support@lumochat.app';

  @override
  String get profileMenuReportBug => 'Report bug';

  @override
  String get profileReportBugTitle => 'Report bug';

  @override
  String get profileReportBugMessage => 'Send bugs to: bug@lumochat.app';

  @override
  String get profileMenuAbout => 'About';

  @override
  String get profileAboutTitle => 'About';

  @override
  String get profileAboutMessage => 'LumoChat - Real-time connection and messaging.';

  @override
  String get profileMenuNotifications => 'Notifications';

  @override
  String get profileLogout => 'Log out';

  @override
  String profileLogoutError(String error) {
    return 'Log out failed: $error';
  }

  @override
  String profileSaveSettingFailed(String error) {
    return 'Failed to save setting: $error';
  }

  @override
  String profileVersion(String version) {
    return 'LumoChat v$version';
  }
}
