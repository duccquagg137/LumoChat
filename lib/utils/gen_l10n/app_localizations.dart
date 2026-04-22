import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen_l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'LumoChat'**
  String get appTitle;

  /// Bottom navigation label for messages tab
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navChats;

  /// Bottom navigation label for groups tab
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get navGroups;

  /// Bottom navigation label for contacts tab
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get navContacts;

  /// Bottom navigation label for profile tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Generic unexpected error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonUnexpectedError;

  /// Generic network error message
  ///
  /// In en, this message translates to:
  /// **'Network error. Please try again.'**
  String get commonErrorNetwork;

  /// Shown when permission is denied
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to perform this action.'**
  String get commonErrorPermissionDenied;

  /// Shown when backend service is unavailable
  ///
  /// In en, this message translates to:
  /// **'Service is temporarily unavailable. Please try again later.'**
  String get commonErrorServiceUnavailable;

  /// Shown when the request exceeds timeout
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get commonErrorTimeout;

  /// Shown when user is unauthenticated
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get commonErrorUnauthenticated;

  /// Shown when provided input is invalid
  ///
  /// In en, this message translates to:
  /// **'Invalid input. Please review and try again.'**
  String get commonErrorInvalidInput;

  /// Shown when data conflict occurs
  ///
  /// In en, this message translates to:
  /// **'This action conflicts with current data.'**
  String get commonErrorConflict;

  /// Shown when requested data does not exist
  ///
  /// In en, this message translates to:
  /// **'Requested data was not found.'**
  String get commonErrorNotFound;

  /// Shown when search has no result
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get commonNoSearchResults;

  /// Generic cancel label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Generic retry action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Generic add friend action
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get commonAddFriend;

  /// Close label for dialogs
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Generic online status
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get commonOnline;

  /// Generic offline status
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get commonOffline;

  /// Generic delete label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Generic pin label
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get commonPin;

  /// Generic unpin label
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get commonUnpin;

  /// Generic hide label
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get commonHide;

  /// Generic leave label
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get commonLeave;

  /// Generic save label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Short loading label for in-progress actions
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get commonLoading;

  /// Generic more options label
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// Hint text in chat list search box
  ///
  /// In en, this message translates to:
  /// **'Search conversations...'**
  String get chatListSearchHint;

  /// Message when user has no friends
  ///
  /// In en, this message translates to:
  /// **'You have no friends yet. Add friends in the Contacts tab.'**
  String get chatListNoFriendsPrompt;

  /// Message when there are no conversations
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatListNoConversations;

  /// Story bubble label for current user
  ///
  /// In en, this message translates to:
  /// **'Your story'**
  String get chatListYourStory;

  /// Action label to open current user's active story
  ///
  /// In en, this message translates to:
  /// **'View my story'**
  String get storyActionViewMyStory;

  /// Action label to add a new story
  ///
  /// In en, this message translates to:
  /// **'Add new story'**
  String get storyActionAddStory;

  /// Dialog title when composing a story
  ///
  /// In en, this message translates to:
  /// **'Create story'**
  String get storyComposeTitle;

  /// Hint for story caption input
  ///
  /// In en, this message translates to:
  /// **'Write a caption...'**
  String get storyCaptionHint;

  /// Label for story visibility selector
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get storyVisibilityLabel;

  /// Story visibility option for friends
  ///
  /// In en, this message translates to:
  /// **'Friends only'**
  String get storyVisibilityFriends;

  /// Story visibility option for all users
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get storyVisibilityPublic;

  /// Action label to publish story
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get storyPublishAction;

  /// Snackbar shown after posting story successfully
  ///
  /// In en, this message translates to:
  /// **'Story posted'**
  String get storyPublishSuccess;

  /// Error message when posting story fails
  ///
  /// In en, this message translates to:
  /// **'Unable to post story: {error}'**
  String storyPublishFailed(String error);

  /// Story source action for picking a photo in gallery
  ///
  /// In en, this message translates to:
  /// **'Photo from gallery'**
  String get storySourcePhotoGallery;

  /// Story source action for capturing photo from camera
  ///
  /// In en, this message translates to:
  /// **'Photo from camera'**
  String get storySourcePhotoCamera;

  /// Story source action for picking a video in gallery
  ///
  /// In en, this message translates to:
  /// **'Video from gallery'**
  String get storySourceVideoGallery;

  /// Story source action for capturing video from camera
  ///
  /// In en, this message translates to:
  /// **'Video from camera'**
  String get storySourceVideoCamera;

  /// Fallback title shown when video story preview is unavailable
  ///
  /// In en, this message translates to:
  /// **'Video story'**
  String get storyViewerVideoFallback;

  /// Relative time label for newly posted stories
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get storyViewerNow;

  /// Title for sheet showing who viewed a story
  ///
  /// In en, this message translates to:
  /// **'Story viewers'**
  String get storyAudienceTitle;

  /// Compact label showing number of story views
  ///
  /// In en, this message translates to:
  /// **'{count} views'**
  String storyAudienceCount(String count);

  /// Empty state when a story has no viewers
  ///
  /// In en, this message translates to:
  /// **'No one has viewed this story yet'**
  String get storyAudienceEmpty;

  /// Label shown for viewers that have not reacted to a story
  ///
  /// In en, this message translates to:
  /// **'No reaction'**
  String get storyAudienceNoReaction;

  /// Dialog title for deleting story
  ///
  /// In en, this message translates to:
  /// **'Delete story?'**
  String get storyDeleteTitle;

  /// Dialog body for confirming story deletion
  ///
  /// In en, this message translates to:
  /// **'This story will be removed immediately.'**
  String get storyDeleteConfirm;

  /// Snackbar shown after deleting story
  ///
  /// In en, this message translates to:
  /// **'Story deleted'**
  String get storyDeleteSuccess;

  /// Snackbar shown when deleting story fails
  ///
  /// In en, this message translates to:
  /// **'Unable to delete story'**
  String get storyDeleteFailed;

  /// Title for story image editor screen before publish
  ///
  /// In en, this message translates to:
  /// **'Edit story'**
  String get storyEditorTitle;

  /// Tooltip for resetting zoom and pan in story image editor
  ///
  /// In en, this message translates to:
  /// **'Reset zoom'**
  String get storyEditorResetZoom;

  /// Hint text for story overlay text input
  ///
  /// In en, this message translates to:
  /// **'Add text on your story...'**
  String get storyEditorTextHint;

  /// Hint shown in story editor for moving overlay text
  ///
  /// In en, this message translates to:
  /// **'Drag text directly on photo to reposition'**
  String get storyEditorTextDragHint;

  /// Label for text size control in story editor
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get storyEditorTextSizeLabel;

  /// Label for text color control in story editor
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get storyEditorTextColorLabel;

  /// Tooltip for toggling bold overlay text in story editor
  ///
  /// In en, this message translates to:
  /// **'Bold text'**
  String get storyEditorTextBold;

  /// Primary action to confirm edited story image
  ///
  /// In en, this message translates to:
  /// **'Use this photo'**
  String get storyEditorUsePhoto;

  /// Snackbar shown when story image editor fails to export
  ///
  /// In en, this message translates to:
  /// **'Could not apply edits. Please try again.'**
  String get storyEditorExportFailed;

  /// Label for selecting a music track when composing story
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get storyMusicTrackLabel;

  /// Option label for story without music
  ///
  /// In en, this message translates to:
  /// **'No music'**
  String get storyMusicNone;

  /// Label for music start offset in story composer
  ///
  /// In en, this message translates to:
  /// **'Start at {time}'**
  String storyMusicStartLabel(String time);

  /// Label for story music volume
  ///
  /// In en, this message translates to:
  /// **'Volume {percent}'**
  String storyMusicVolumeLabel(String percent);

  /// Badge text shown when story has music
  ///
  /// In en, this message translates to:
  /// **'Music: {track}'**
  String storyMusicPlayingLabel(String track);

  /// Default last message text
  ///
  /// In en, this message translates to:
  /// **'Tap to start chatting'**
  String get chatListTapToStart;

  /// Typing indicator text
  ///
  /// In en, this message translates to:
  /// **'typing...'**
  String get chatListTyping;

  /// Hint text for searching messages inside a conversation
  ///
  /// In en, this message translates to:
  /// **'Search in conversation...'**
  String get chatSearchHint;

  /// Shown when conversation search has no matching messages
  ///
  /// In en, this message translates to:
  /// **'No matching messages'**
  String get chatSearchNoMatches;

  /// Hint text in chat input field
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatInputHint;

  /// Label shown above reply preview in input area
  ///
  /// In en, this message translates to:
  /// **'Replying'**
  String get chatReplyingTo;

  /// Placeholder text for image message references
  ///
  /// In en, this message translates to:
  /// **'📷 [image]'**
  String get chatImagePlaceholder;

  /// Shown when replied message no longer exists
  ///
  /// In en, this message translates to:
  /// **'Message unavailable'**
  String get chatMessageDeleted;

  /// Shown when message was recalled
  ///
  /// In en, this message translates to:
  /// **'Message recalled'**
  String get chatMessageRecalled;

  /// Delivery status label when message is sent
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get chatStatusSent;

  /// Delivery status label when message is delivered
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get chatStatusDelivered;

  /// Delivery status label when message is read
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get chatStatusRead;

  /// Snackbar text while uploading image
  ///
  /// In en, this message translates to:
  /// **'Uploading image...'**
  String get chatUploadingImage;

  /// Snackbar text when image upload fails
  ///
  /// In en, this message translates to:
  /// **'Image upload failed'**
  String get chatImageUploadFailed;

  /// Error message when image upload fails with reason
  ///
  /// In en, this message translates to:
  /// **'Image upload failed: {error}'**
  String chatImageUploadFailedWithReason(String error);

  /// Retry action label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get chatRetry;

  /// Error message when sending message fails
  ///
  /// In en, this message translates to:
  /// **'Send failed: {error}'**
  String chatSendFailed(String error);

  /// Error when selecting image from camera/gallery fails
  ///
  /// In en, this message translates to:
  /// **'Unable to pick image: {error}'**
  String chatImagePickFailed(String error);

  /// Reply action label in message context menu
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatContextReply;

  /// Copy action label in message context menu
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatContextCopy;

  /// Pin message action label in message context menu
  ///
  /// In en, this message translates to:
  /// **'Pin message'**
  String get chatContextPinMessage;

  /// Unpin message action label in message context menu
  ///
  /// In en, this message translates to:
  /// **'Unpin message'**
  String get chatContextUnpinMessage;

  /// Title for pinned message banner in chat screen
  ///
  /// In en, this message translates to:
  /// **'Pinned message'**
  String get chatPinnedMessageTitle;

  /// Toast/snackbar text when message is copied
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get chatCopied;

  /// Action label for recalling a message for current user only
  ///
  /// In en, this message translates to:
  /// **'Recall for me'**
  String get chatRecallForMe;

  /// Success message after recalling a message for current user
  ///
  /// In en, this message translates to:
  /// **'Message recalled for you'**
  String get chatRecalledForMeSuccess;

  /// Action label for recalling message for everyone
  ///
  /// In en, this message translates to:
  /// **'Recall for everyone'**
  String get chatRecallForEveryone;

  /// Success message after recalling message for everyone
  ///
  /// In en, this message translates to:
  /// **'Message recalled for everyone'**
  String get chatRecalledForEveryoneSuccess;

  /// Success message after pinning a message
  ///
  /// In en, this message translates to:
  /// **'Message pinned'**
  String get chatMessagePinnedSuccess;

  /// Success message after unpinning a message
  ///
  /// In en, this message translates to:
  /// **'Message unpinned'**
  String get chatMessageUnpinnedSuccess;

  /// Error when pin/unpin message action fails
  ///
  /// In en, this message translates to:
  /// **'Pinned message action failed: {error}'**
  String chatPinnedActionFailed(String error);

  /// Success message after pinning a chat
  ///
  /// In en, this message translates to:
  /// **'Chat has been pinned'**
  String get chatListPinSuccess;

  /// Success message after unpinning a chat
  ///
  /// In en, this message translates to:
  /// **'Chat has been unpinned'**
  String get chatListUnpinSuccess;

  /// Success message after hiding a chat
  ///
  /// In en, this message translates to:
  /// **'Chat has been hidden'**
  String get chatListHideSuccess;

  /// Success message after deleting chat for current user
  ///
  /// In en, this message translates to:
  /// **'Chat removed from your list'**
  String get chatListDeleteSuccess;

  /// Error message for chat list actions
  ///
  /// In en, this message translates to:
  /// **'Chat action failed: {error}'**
  String chatListActionFailed(String error);

  /// Error message when contact action fails
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String contactsActionFailed(String error);

  /// Error while loading current user profile in contacts screen
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile'**
  String get contactsLoadProfileError;

  /// Error while loading contacts list
  ///
  /// In en, this message translates to:
  /// **'Failed to load contacts'**
  String get contactsLoadContactsError;

  /// Hint text in contacts search box
  ///
  /// In en, this message translates to:
  /// **'Search friends...'**
  String get contactsSearchHint;

  /// Filter chip for showing all items in contacts screen
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get contactsFilterAll;

  /// Filter chip for showing requests in contacts screen
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get contactsFilterRequests;

  /// Filter chip for showing friends in contacts screen
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get contactsFilterFriends;

  /// Filter chip for showing discover suggestions in contacts screen
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get contactsFilterDiscover;

  /// Quick action label for received invites
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get contactsQuickInvites;

  /// Quick action label for sent invites
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get contactsQuickSent;

  /// Quick action label for friends
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get contactsQuickFriends;

  /// Section title showing number of online friends
  ///
  /// In en, this message translates to:
  /// **'Friends online ({count})'**
  String contactsOnlineFriends(int count);

  /// Section title for received friend requests
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get contactsSectionFriendRequests;

  /// Success message after rejecting request
  ///
  /// In en, this message translates to:
  /// **'Invitation declined'**
  String get contactsRejectedInvite;

  /// Success message after accepting request
  ///
  /// In en, this message translates to:
  /// **'Friend request accepted'**
  String get contactsAcceptedFriend;

  /// Section title for sent requests
  ///
  /// In en, this message translates to:
  /// **'Sent invitations'**
  String get contactsSectionSent;

  /// Subtitle for pending sent request
  ///
  /// In en, this message translates to:
  /// **'Waiting for response'**
  String get contactsPendingResponse;

  /// Success message after canceling request
  ///
  /// In en, this message translates to:
  /// **'Invitation canceled'**
  String get contactsCanceledInvite;

  /// Section title for friend list
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get contactsSectionFriends;

  /// Success message after unfriend
  ///
  /// In en, this message translates to:
  /// **'Removed from friends'**
  String get contactsUnfriended;

  /// Section title for suggestions
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get contactsSectionDiscover;

  /// Success message after sending friend request
  ///
  /// In en, this message translates to:
  /// **'Friend request sent'**
  String get contactsSentInvite;

  /// Empty state for contacts filters
  ///
  /// In en, this message translates to:
  /// **'No matching data'**
  String get contactsNoMatchingData;

  /// Empty state when no users are available in contacts
  ///
  /// In en, this message translates to:
  /// **'No users available to display.'**
  String get contactsEmptyNoUsers;

  /// Empty state for requests filter in contacts
  ///
  /// In en, this message translates to:
  /// **'No friend requests right now.'**
  String get contactsEmptyRequests;

  /// Empty state for friends filter in contacts
  ///
  /// In en, this message translates to:
  /// **'You have no friends yet.'**
  String get contactsEmptyFriends;

  /// Empty state for discover filter in contacts
  ///
  /// In en, this message translates to:
  /// **'No friend suggestions available.'**
  String get contactsEmptyDiscover;

  /// Fallback subtitle for online friend
  ///
  /// In en, this message translates to:
  /// **'Active now'**
  String get contactsStatusActive;

  /// Fallback subtitle for offline friend
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get contactsStatusOffline;

  /// Title of groups screen
  ///
  /// In en, this message translates to:
  /// **'Group chats'**
  String get groupsTitle;

  /// Hint text for groups search input
  ///
  /// In en, this message translates to:
  /// **'Search groups by name or message...'**
  String get groupsSearchHint;

  /// Sort option for recent group activity
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get groupsSortRecent;

  /// Sort option for group name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get groupsSortName;

  /// Sort option for number of members
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get groupsSortMembers;

  /// Error message while loading groups
  ///
  /// In en, this message translates to:
  /// **'Error loading groups: {error}'**
  String groupsLoadError(String error);

  /// Empty state when user has no groups
  ///
  /// In en, this message translates to:
  /// **'You have not joined any group yet'**
  String get groupsEmpty;

  /// Empty state when searching groups has no results
  ///
  /// In en, this message translates to:
  /// **'No groups found for this search'**
  String get groupsNoSearchResults;

  /// Fallback group name
  ///
  /// In en, this message translates to:
  /// **'Unnamed group'**
  String get groupsUnnamed;

  /// Fallback group subtitle when no last message exists
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get groupsNoMessagesYet;

  /// Group member count label
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String groupsMemberCount(int count);

  /// Action label to add members into group
  ///
  /// In en, this message translates to:
  /// **'Add members'**
  String get groupsActionAddMembers;

  /// Action label to leave group
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get groupsActionLeaveGroup;

  /// Action label to delete group
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get groupsActionDeleteGroup;

  /// Error message for group action
  ///
  /// In en, this message translates to:
  /// **'Group action failed: {error}'**
  String groupsActionFailed(String error);

  /// Success message after pinning a group conversation
  ///
  /// In en, this message translates to:
  /// **'Group chat pinned'**
  String get groupsPinSuccess;

  /// Success message after unpinning a group conversation
  ///
  /// In en, this message translates to:
  /// **'Group chat unpinned'**
  String get groupsUnpinSuccess;

  /// Dialog title for adding group members
  ///
  /// In en, this message translates to:
  /// **'Add members to group'**
  String get groupsAddMembersDialogTitle;

  /// Hint text for searching members in add member dialog
  ///
  /// In en, this message translates to:
  /// **'Search members...'**
  String get groupsAddMembersSearchHint;

  /// Message when user has no friends to add
  ///
  /// In en, this message translates to:
  /// **'You have no friends to add into this group'**
  String get groupsAddMembersNoFriends;

  /// Message when no candidate remains for adding
  ///
  /// In en, this message translates to:
  /// **'No suitable friends left to add'**
  String get groupsAddMembersNoCandidates;

  /// Success message after adding group members
  ///
  /// In en, this message translates to:
  /// **'Added {count} members'**
  String groupsAddMembersSuccess(int count);

  /// Confirmation title for leaving group
  ///
  /// In en, this message translates to:
  /// **'Confirm leaving group'**
  String get groupsLeaveConfirmTitle;

  /// Confirmation message for leaving group
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave \"{groupName}\"?'**
  String groupsLeaveConfirmMessage(String groupName);

  /// Success message after leaving group
  ///
  /// In en, this message translates to:
  /// **'You left the group'**
  String get groupsLeaveSuccess;

  /// Confirmation title for deleting group
  ///
  /// In en, this message translates to:
  /// **'Confirm deleting group'**
  String get groupsDeleteConfirmTitle;

  /// Confirmation message for deleting group
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{groupName}\"? This action cannot be undone.'**
  String groupsDeleteConfirmMessage(String groupName);

  /// Message when current user is not allowed to delete group
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to delete this group'**
  String get groupsDeleteNotAllowed;

  /// Success message after deleting group
  ///
  /// In en, this message translates to:
  /// **'Group deleted'**
  String get groupsDeleteSuccess;

  /// Title of create group screen
  ///
  /// In en, this message translates to:
  /// **'Create new group'**
  String get groupsCreateTitle;

  /// Create action label in create group screen
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get groupsCreateAction;

  /// Default group name when user does not type one
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get groupsCreateDefaultName;

  /// Hint for group name input
  ///
  /// In en, this message translates to:
  /// **'Group name (optional)'**
  String get groupsCreateNameHint;

  /// Hint for group description input
  ///
  /// In en, this message translates to:
  /// **'Group description (optional)'**
  String get groupsCreateDescriptionHint;

  /// Count of selected members in create group screen
  ///
  /// In en, this message translates to:
  /// **'Selected ({count})'**
  String groupsCreateSelectedCount(int count);

  /// Hint for searching friends in create group screen
  ///
  /// In en, this message translates to:
  /// **'Search friends to add...'**
  String get groupsCreateSearchHint;

  /// Empty state when creating group without friends
  ///
  /// In en, this message translates to:
  /// **'You have no friends to add into a group.'**
  String get groupsCreateNoFriends;

  /// Bottom button label for creating a group
  ///
  /// In en, this message translates to:
  /// **'Create group with {count} members'**
  String groupsCreateButton(int count);

  /// Snackbar text while creating a group
  ///
  /// In en, this message translates to:
  /// **'Creating group...'**
  String get groupsCreateInProgress;

  /// Error text when group creation fails
  ///
  /// In en, this message translates to:
  /// **'Create group failed: {error}'**
  String groupsCreateFailed(String error);

  /// Error shown when loading profile data in create group screen
  ///
  /// In en, this message translates to:
  /// **'Unable to load your profile.'**
  String get groupsCreateLoadProfileError;

  /// Error shown when loading friend data in create group screen
  ///
  /// In en, this message translates to:
  /// **'Unable to load your friends list.'**
  String get groupsCreateLoadFriendsError;

  /// Validation error when email or password is missing
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields.'**
  String get authValidationRequiredFields;

  /// Validation error when name is missing during sign up
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get authValidationNameRequired;

  /// Validation error when password confirmation mismatches
  ///
  /// In en, this message translates to:
  /// **'Password confirmation does not match.'**
  String get authValidationPasswordMismatch;

  /// Validation error when phone number is missing
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number.'**
  String get authValidationPhoneRequired;

  /// Validation error when OTP is empty or invalid
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid OTP code.'**
  String get authValidationOtpRequired;

  /// Error shown when login credentials are invalid
  ///
  /// In en, this message translates to:
  /// **'Invalid login credentials.'**
  String get authErrorInvalidCredentials;

  /// Error shown when signing up with an existing email
  ///
  /// In en, this message translates to:
  /// **'This email is already in use.'**
  String get authErrorEmailAlreadyInUse;

  /// Error shown when provided password is weak
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Please choose a stronger one.'**
  String get authErrorWeakPassword;

  /// Error shown when auth requests are throttled
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later.'**
  String get authErrorTooManyRequests;

  /// Error shown when OTP verification fails
  ///
  /// In en, this message translates to:
  /// **'OTP is invalid or has expired.'**
  String get authErrorInvalidOtp;

  /// Error shown when phone number format is invalid
  ///
  /// In en, this message translates to:
  /// **'Phone number is invalid.'**
  String get authErrorInvalidPhoneNumber;

  /// Error shown when Firebase SMS quota is exceeded
  ///
  /// In en, this message translates to:
  /// **'SMS quota reached for today. Please try again later.'**
  String get authErrorSmsQuotaExceeded;

  /// Error shown when Firebase billing is disabled for phone auth
  ///
  /// In en, this message translates to:
  /// **'Firebase Billing is not enabled for real SMS verification.'**
  String get authErrorBillingNotEnabled;

  /// Error shown when auth method is disabled in Firebase
  ///
  /// In en, this message translates to:
  /// **'This sign-in method is not enabled.'**
  String get authErrorOperationNotAllowed;

  /// Error message for automatic phone verification failure
  ///
  /// In en, this message translates to:
  /// **'Auto verification failed: {error}'**
  String authErrorAutoVerificationFailed(String error);

  /// Error message when phone number verification fails
  ///
  /// In en, this message translates to:
  /// **'Verification failed: {error}'**
  String authErrorVerificationFailed(String error);

  /// Error message when sending OTP fails
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP: {error}'**
  String authErrorSendOtpFailed(String error);

  /// Error message when Google sign-in fails
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed: {error}'**
  String authErrorGoogleFailed(String error);

  /// Temporary message for unavailable Apple sign-in
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in is coming soon.'**
  String get authAppleComingSoon;

  /// Fallback value for missing profile fields
  ///
  /// In en, this message translates to:
  /// **'Not updated'**
  String get profileNotUpdated;

  /// Profile load error message
  ///
  /// In en, this message translates to:
  /// **'Unable to load profile'**
  String get profileLoadError;

  /// Fallback user name
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileFallbackUser;

  /// Fallback profile bio
  ///
  /// In en, this message translates to:
  /// **'Using LumoChat'**
  String get profileFallbackBio;

  /// Summary title for copied profile text
  ///
  /// In en, this message translates to:
  /// **'LumoChat Profile'**
  String get profileSummaryTitle;

  /// Label for name in profile summary
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileSummaryName;

  /// Label for email in profile summary
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileSummaryEmail;

  /// Label for phone in profile summary
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profileSummaryPhone;

  /// Label for address in profile summary
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get profileSummaryAddress;

  /// Label for city in profile summary
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileSummaryCity;

  /// Label for gender in profile summary
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get profileSummaryGender;

  /// Label for birth date in profile summary
  ///
  /// In en, this message translates to:
  /// **'Birth date'**
  String get profileSummaryBirthDate;

  /// Label for occupation in profile summary
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get profileSummaryOccupation;

  /// Label for website in profile summary
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get profileSummaryWebsite;

  /// Success message after copying profile summary
  ///
  /// In en, this message translates to:
  /// **'Profile information copied'**
  String get profileCopySummarySuccess;

  /// Friends stat label
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get profileStatFriends;

  /// Groups stat label
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get profileStatGroups;

  /// Status stat label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get profileStatStatus;

  /// Edit profile button label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileEdit;

  /// Share profile button label
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get profileShare;

  /// Section title for basic profile info
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get profileSectionBasicInfo;

  /// Phone field label
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profileFieldPhone;

  /// Address field label
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get profileFieldAddress;

  /// City field label
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileFieldCity;

  /// Gender field label
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get profileFieldGender;

  /// Birth date field label
  ///
  /// In en, this message translates to:
  /// **'Birth date'**
  String get profileFieldBirthDate;

  /// Occupation field label
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get profileFieldOccupation;

  /// Website field label
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get profileFieldWebsite;

  /// Section title for account settings
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileSectionAccount;

  /// Menu item label for personal info
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get profileMenuPersonalInfo;

  /// Menu item label for copying user id
  ///
  /// In en, this message translates to:
  /// **'Copy user ID'**
  String get profileMenuCopyUserId;

  /// Success message after copying user id
  ///
  /// In en, this message translates to:
  /// **'User ID copied'**
  String get profileCopyUserIdSuccess;

  /// Menu item label for security
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get profileMenuSecurity;

  /// Security dialog title
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get profileSecurityTitle;

  /// Security dialog message
  ///
  /// In en, this message translates to:
  /// **'Advanced security features will be available soon.'**
  String get profileSecurityMessage;

  /// Section title for customization
  ///
  /// In en, this message translates to:
  /// **'Customization'**
  String get profileSectionCustomization;

  /// Menu label for dark mode toggle
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get profileMenuDarkMode;

  /// Menu label for language selector
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileMenuLanguage;

  /// Language option label for Vietnamese
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get profileLanguageVietnamese;

  /// Language option label for English
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get profileLanguageEnglish;

  /// Language selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get profileLanguageDialogTitle;

  /// Error while saving language setting
  ///
  /// In en, this message translates to:
  /// **'Failed to save language setting: {error}'**
  String profileLanguageSaveFailed(String error);

  /// Section title for support
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get profileSectionSupport;

  /// Menu label for help center
  ///
  /// In en, this message translates to:
  /// **'Help center'**
  String get profileMenuHelpCenter;

  /// Support dialog title
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get profileHelpTitle;

  /// Support dialog message
  ///
  /// In en, this message translates to:
  /// **'Contact: support@lumochat.app'**
  String get profileHelpMessage;

  /// Menu label for report bug
  ///
  /// In en, this message translates to:
  /// **'Report bug'**
  String get profileMenuReportBug;

  /// Report bug dialog title
  ///
  /// In en, this message translates to:
  /// **'Report bug'**
  String get profileReportBugTitle;

  /// Report bug dialog message
  ///
  /// In en, this message translates to:
  /// **'Send bugs to: bug@lumochat.app'**
  String get profileReportBugMessage;

  /// Menu label for about
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileMenuAbout;

  /// About dialog title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileAboutTitle;

  /// About dialog message
  ///
  /// In en, this message translates to:
  /// **'LumoChat - Real-time connection and messaging.'**
  String get profileAboutMessage;

  /// Menu label for notifications toggle
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileMenuNotifications;

  /// Log out button label
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogout;

  /// Error message when logout fails
  ///
  /// In en, this message translates to:
  /// **'Log out failed: {error}'**
  String profileLogoutError(String error);

  /// Error while saving profile setting
  ///
  /// In en, this message translates to:
  /// **'Failed to save setting: {error}'**
  String profileSaveSettingFailed(String error);

  /// Application version text
  ///
  /// In en, this message translates to:
  /// **'LumoChat v{version}'**
  String profileVersion(String version);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'vi': return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
