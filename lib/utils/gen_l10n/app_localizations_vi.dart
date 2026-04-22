import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'LumoChat';

  @override
  String get navChats => 'Tin nhắn';

  @override
  String get navGroups => 'Nhóm';

  @override
  String get navContacts => 'Danh bạ';

  @override
  String get navProfile => 'Cá nhân';

  @override
  String get commonUnexpectedError => 'Đã xảy ra lỗi';

  @override
  String get commonErrorNetwork => 'Lỗi kết nối mạng. Vui lòng thử lại.';

  @override
  String get commonErrorPermissionDenied => 'Bạn không có quyền thực hiện thao tác này.';

  @override
  String get commonErrorServiceUnavailable => 'Dịch vụ đang tạm thời gián đoạn. Vui lòng thử lại sau.';

  @override
  String get commonErrorTimeout => 'Yêu cầu đang bị quá thời gian. Vui lòng thử lại.';

  @override
  String get commonErrorUnauthenticated => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';

  @override
  String get commonErrorInvalidInput => 'Dữ liệu không hợp lệ. Vui lòng kiểm tra và thử lại.';

  @override
  String get commonErrorConflict => 'Thao tác bị xung đột với dữ liệu hiện tại.';

  @override
  String get commonErrorNotFound => 'Không tìm thấy dữ liệu yêu cầu.';

  @override
  String get commonNoSearchResults => 'Không tìm thấy kết quả';

  @override
  String get commonCancel => 'Hủy';

  @override
  String get commonRetry => 'Thử lại';

  @override
  String get commonAddFriend => 'Kết bạn';

  @override
  String get commonClose => 'Đóng';

  @override
  String get commonOnline => 'Trực tuyến';

  @override
  String get commonOffline => 'Ngoại tuyến';

  @override
  String get commonDelete => 'Xóa';

  @override
  String get commonPin => 'Ghim';

  @override
  String get commonUnpin => 'Bỏ ghim';

  @override
  String get commonHide => 'Ẩn';

  @override
  String get commonLeave => 'Rời nhóm';

  @override
  String get commonSave => 'Lưu';

  @override
  String get commonLoading => 'Đang xử lý...';

  @override
  String get commonMore => 'Thêm';

  @override
  String get chatListSearchHint => 'Tìm kiếm cuộc trò chuyện...';

  @override
  String get chatListNoFriendsPrompt => 'Bạn chưa có bạn bè nào. Hãy kết bạn ở tab Danh bạ.';

  @override
  String get chatListNoConversations => 'Chưa có cuộc trò chuyện nào';

  @override
  String get chatListYourStory => 'Tin của bạn';

  @override
  String get storyActionViewMyStory => 'Xem tin của bạn';

  @override
  String get storyActionAddStory => 'Đăng tin mới';

  @override
  String get storyComposeTitle => 'Tạo tin';

  @override
  String get storyCaptionHint => 'Nhập chú thích...';

  @override
  String get storyVisibilityLabel => 'Quyền xem';

  @override
  String get storyVisibilityFriends => 'Chỉ bạn bè';

  @override
  String get storyVisibilityPublic => 'Công khai';

  @override
  String get storyPublishAction => 'Đăng';

  @override
  String get storyPublishSuccess => 'Đã đăng tin';

  @override
  String storyPublishFailed(String error) {
    return 'Không thể đăng tin: $error';
  }

  @override
  String get storySourcePhotoGallery => 'Ảnh từ thư viện';

  @override
  String get storySourcePhotoCamera => 'Ảnh từ camera';

  @override
  String get storySourceVideoGallery => 'Video từ thư viện';

  @override
  String get storySourceVideoCamera => 'Video từ camera';

  @override
  String get storyViewerVideoFallback => 'Tin video';

  @override
  String get storyViewerNow => 'vừa xong';

  @override
  String get storyAudienceTitle => 'Người đã xem';

  @override
  String storyAudienceCount(String count) {
    return '$count lượt xem';
  }

  @override
  String get storyAudienceEmpty => 'Chưa có ai xem story này';

  @override
  String get storyAudienceNoReaction => 'Chưa thả cảm xúc';

  @override
  String get storyDeleteTitle => 'Xóa story này?';

  @override
  String get storyDeleteConfirm => 'Story sẽ bị xóa ngay lập tức.';

  @override
  String get storyDeleteSuccess => 'Đã xóa story';

  @override
  String get storyDeleteFailed => 'Không thể xóa story';

  @override
  String get storyEditorTitle => 'Chỉnh sửa tin';

  @override
  String get storyEditorResetZoom => 'Đặt lại thu phóng';

  @override
  String get storyEditorTextHint => 'Thêm chữ lên story...';

  @override
  String get storyEditorTextDragHint => 'Kéo chữ trực tiếp trên ảnh để đổi vị trí';

  @override
  String get storyEditorTextSizeLabel => 'Cỡ chữ';

  @override
  String get storyEditorTextColorLabel => 'Màu chữ';

  @override
  String get storyEditorTextBold => 'Chữ đậm';

  @override
  String get storyEditorUsePhoto => 'Dùng ảnh này';

  @override
  String get storyEditorExportFailed => 'Không thể áp dụng chỉnh sửa. Vui lòng thử lại.';

  @override
  String get storyMusicTrackLabel => 'Nhạc';

  @override
  String get storyMusicNone => 'Không dùng nhạc';

  @override
  String storyMusicStartLabel(String time) {
    return 'Bắt đầu từ $time';
  }

  @override
  String storyMusicVolumeLabel(String percent) {
    return 'Âm lượng $percent';
  }

  @override
  String storyMusicPlayingLabel(String track) {
    return 'Nhạc: $track';
  }

  @override
  String get chatListTapToStart => 'Chạm để bắt đầu trò chuyện';

  @override
  String get chatListTyping => 'đang nhập...';

  @override
  String get chatSearchHint => 'Tìm trong cuộc trò chuyện...';

  @override
  String get chatSearchNoMatches => 'Không có tin nhắn phù hợp';

  @override
  String get chatInputHint => 'Nhập tin nhắn...';

  @override
  String get chatReplyingTo => 'Trả lời';

  @override
  String get chatImagePlaceholder => '📷 [ảnh]';

  @override
  String get chatMessageDeleted => 'Tin nhắn không còn tồn tại';

  @override
  String get chatMessageRecalled => 'Tin nhắn đã thu hồi';

  @override
  String get chatStatusSent => 'Đã gửi';

  @override
  String get chatStatusDelivered => 'Đã nhận';

  @override
  String get chatStatusRead => 'Đã xem';

  @override
  String get chatUploadingImage => 'Đang tải ảnh lên...';

  @override
  String get chatImageUploadFailed => 'Tải ảnh thất bại';

  @override
  String chatImageUploadFailedWithReason(String error) {
    return 'Tải ảnh thất bại: $error';
  }

  @override
  String get chatRetry => 'Thử lại';

  @override
  String chatSendFailed(String error) {
    return 'Gửi thất bại: $error';
  }

  @override
  String chatImagePickFailed(String error) {
    return 'Không thể chọn ảnh: $error';
  }

  @override
  String get chatContextReply => 'Trả lời';

  @override
  String get chatContextCopy => 'Sao chép';

  @override
  String get chatContextPinMessage => 'Ghim tin nhắn';

  @override
  String get chatContextUnpinMessage => 'Bỏ ghim tin nhắn';

  @override
  String get chatPinnedMessageTitle => 'Tin nhắn đã ghim';

  @override
  String get chatCopied => 'Đã sao chép';

  @override
  String get chatRecallForMe => 'Thu hồi cho bạn';

  @override
  String get chatRecalledForMeSuccess => 'Đã thu hồi cho bạn';

  @override
  String get chatRecallForEveryone => 'Thu hồi cho mọi người';

  @override
  String get chatRecalledForEveryoneSuccess => 'Đã thu hồi cho mọi người';

  @override
  String get chatMessagePinnedSuccess => 'Đã ghim tin nhắn';

  @override
  String get chatMessageUnpinnedSuccess => 'Đã bỏ ghim tin nhắn';

  @override
  String chatPinnedActionFailed(String error) {
    return 'Thao tác ghim tin nhắn thất bại: $error';
  }

  @override
  String get chatListPinSuccess => 'Đã ghim đoạn chat';

  @override
  String get chatListUnpinSuccess => 'Đã bỏ ghim đoạn chat';

  @override
  String get chatListHideSuccess => 'Đã ẩn đoạn chat';

  @override
  String get chatListDeleteSuccess => 'Đã xóa đoạn chat khỏi danh sách';

  @override
  String chatListActionFailed(String error) {
    return 'Thao tác đoạn chat thất bại: $error';
  }

  @override
  String contactsActionFailed(String error) {
    return 'Thao tác thất bại: $error';
  }

  @override
  String get contactsLoadProfileError => 'Lỗi tải hồ sơ';

  @override
  String get contactsLoadContactsError => 'Lỗi tải danh bạ';

  @override
  String get contactsSearchHint => 'Tìm bạn bè...';

  @override
  String get contactsFilterAll => 'Tất cả';

  @override
  String get contactsFilterRequests => 'Lời mời';

  @override
  String get contactsFilterFriends => 'Bạn bè';

  @override
  String get contactsFilterDiscover => 'Khám phá';

  @override
  String get contactsQuickInvites => 'Lời mời';

  @override
  String get contactsQuickSent => 'Đã gửi';

  @override
  String get contactsQuickFriends => 'Bạn bè';

  @override
  String contactsOnlineFriends(int count) {
    return 'Bạn bè đang trực tuyến ($count)';
  }

  @override
  String get contactsSectionFriendRequests => 'Lời mời kết bạn';

  @override
  String get contactsRejectedInvite => 'Đã từ chối lời mời';

  @override
  String get contactsAcceptedFriend => 'Đã chấp nhận kết bạn';

  @override
  String get contactsSectionSent => 'Đã gửi lời mời';

  @override
  String get contactsPendingResponse => 'Đang chờ phản hồi';

  @override
  String get contactsCanceledInvite => 'Đã hủy lời mời';

  @override
  String get contactsSectionFriends => 'Bạn bè';

  @override
  String get contactsUnfriended => 'Đã xóa bạn bè';

  @override
  String get contactsSectionDiscover => 'Khám phá';

  @override
  String get contactsSentInvite => 'Đã gửi lời mời kết bạn';

  @override
  String get contactsNoMatchingData => 'Không có dữ liệu phù hợp';

  @override
  String get contactsEmptyNoUsers => 'Chưa có người dùng nào để hiển thị.';

  @override
  String get contactsEmptyRequests => 'Không có lời mời kết bạn nào.';

  @override
  String get contactsEmptyFriends => 'Bạn chưa có bạn bè nào.';

  @override
  String get contactsEmptyDiscover => 'Không có gợi ý kết bạn phù hợp.';

  @override
  String get contactsStatusActive => 'Đang hoạt động';

  @override
  String get contactsStatusOffline => 'Ngoại tuyến';

  @override
  String get groupsTitle => 'Nhóm trò chuyện';

  @override
  String get groupsSearchHint => 'Tìm nhóm theo tên hoặc tin nhắn...';

  @override
  String get groupsSortRecent => 'Gần đây';

  @override
  String get groupsSortName => 'Tên nhóm';

  @override
  String get groupsSortMembers => 'Nhiều thành viên';

  @override
  String groupsLoadError(String error) {
    return 'Lỗi tải nhóm: $error';
  }

  @override
  String get groupsEmpty => 'Bạn chưa tham gia nhóm nào';

  @override
  String get groupsNoSearchResults => 'Không tìm thấy nhóm phù hợp';

  @override
  String get groupsUnnamed => 'Nhóm không tên';

  @override
  String get groupsNoMessagesYet => 'Chưa có tin nhắn nào';

  @override
  String groupsMemberCount(int count) {
    return '$count thành viên';
  }

  @override
  String get groupsActionAddMembers => 'Thêm người';

  @override
  String get groupsActionLeaveGroup => 'Rời nhóm';

  @override
  String get groupsActionDeleteGroup => 'Xóa nhóm';

  @override
  String groupsActionFailed(String error) {
    return 'Thao tác nhóm thất bại: $error';
  }

  @override
  String get groupsPinSuccess => 'Đã ghim nhóm trò chuyện';

  @override
  String get groupsUnpinSuccess => 'Đã bỏ ghim nhóm trò chuyện';

  @override
  String get groupsAddMembersDialogTitle => 'Thêm thành viên vào nhóm';

  @override
  String get groupsAddMembersSearchHint => 'Tìm thành viên...';

  @override
  String get groupsAddMembersNoFriends => 'Bạn chưa có bạn bè để thêm vào nhóm';

  @override
  String get groupsAddMembersNoCandidates => 'Không còn bạn bè phù hợp để thêm';

  @override
  String groupsAddMembersSuccess(int count) {
    return 'Đã thêm $count thành viên';
  }

  @override
  String get groupsLeaveConfirmTitle => 'Xác nhận rời nhóm';

  @override
  String groupsLeaveConfirmMessage(String groupName) {
    return 'Bạn có chắc muốn rời nhóm \"$groupName\"?';
  }

  @override
  String get groupsLeaveSuccess => 'Bạn đã rời nhóm';

  @override
  String get groupsDeleteConfirmTitle => 'Xác nhận xóa nhóm';

  @override
  String groupsDeleteConfirmMessage(String groupName) {
    return 'Bạn có chắc muốn xóa nhóm \"$groupName\"? Hành động này không thể hoàn tác.';
  }

  @override
  String get groupsDeleteNotAllowed => 'Bạn không có quyền xóa nhóm này';

  @override
  String get groupsDeleteSuccess => 'Đã xóa nhóm';

  @override
  String get groupsCreateTitle => 'Tạo nhóm mới';

  @override
  String get groupsCreateAction => 'Tạo';

  @override
  String get groupsCreateDefaultName => 'Nhóm mới';

  @override
  String get groupsCreateNameHint => 'Tên nhóm (tùy chọn)';

  @override
  String get groupsCreateDescriptionHint => 'Mô tả nhóm (tùy chọn)';

  @override
  String groupsCreateSelectedCount(int count) {
    return 'Đã chọn ($count)';
  }

  @override
  String get groupsCreateSearchHint => 'Tìm bạn bè để thêm...';

  @override
  String get groupsCreateNoFriends => 'Bạn chưa có bạn bè để thêm vào nhóm.';

  @override
  String groupsCreateButton(int count) {
    return 'Tạo nhóm với $count thành viên';
  }

  @override
  String get groupsCreateInProgress => 'Đang tạo nhóm...';

  @override
  String groupsCreateFailed(String error) {
    return 'Tạo nhóm thất bại: $error';
  }

  @override
  String get groupsCreateLoadProfileError => 'Không thể tải hồ sơ hiện tại.';

  @override
  String get groupsCreateLoadFriendsError => 'Không thể tải danh sách bạn bè.';

  @override
  String get authValidationRequiredFields => 'Vui lòng nhập đầy đủ thông tin.';

  @override
  String get authValidationNameRequired => 'Vui lòng nhập tên.';

  @override
  String get authValidationPasswordMismatch => 'Mật khẩu xác nhận không khớp.';

  @override
  String get authValidationPhoneRequired => 'Vui lòng nhập số điện thoại.';

  @override
  String get authValidationOtpRequired => 'Vui lòng nhập mã OTP hợp lệ.';

  @override
  String get authErrorInvalidCredentials => 'Thông tin đăng nhập không hợp lệ.';

  @override
  String get authErrorEmailAlreadyInUse => 'Email này đã được sử dụng.';

  @override
  String get authErrorWeakPassword => 'Mật khẩu quá yếu. Vui lòng dùng mật khẩu mạnh hơn.';

  @override
  String get authErrorTooManyRequests => 'Bạn thao tác quá nhiều lần. Vui lòng thử lại sau.';

  @override
  String get authErrorInvalidOtp => 'Mã OTP không đúng hoặc đã hết hạn.';

  @override
  String get authErrorInvalidPhoneNumber => 'Số điện thoại không hợp lệ.';

  @override
  String get authErrorSmsQuotaExceeded => 'Đã hết hạn mức gửi SMS hôm nay. Vui lòng thử lại sau.';

  @override
  String get authErrorBillingNotEnabled => 'Dự án Firebase chưa bật Billing để gửi SMS thật.';

  @override
  String get authErrorOperationNotAllowed => 'Phương thức đăng nhập này hiện chưa được bật.';

  @override
  String authErrorAutoVerificationFailed(String error) {
    return 'Xác thực tự động thất bại: $error';
  }

  @override
  String authErrorVerificationFailed(String error) {
    return 'Xác minh thất bại: $error';
  }

  @override
  String authErrorSendOtpFailed(String error) {
    return 'Gửi mã OTP thất bại: $error';
  }

  @override
  String authErrorGoogleFailed(String error) {
    return 'Đăng nhập Google thất bại: $error';
  }

  @override
  String get authAppleComingSoon => 'Đăng nhập Apple sẽ sớm được hỗ trợ.';

  @override
  String get profileNotUpdated => 'Chưa cập nhật';

  @override
  String get profileLoadError => 'Không tải được hồ sơ';

  @override
  String get profileFallbackUser => 'Người dùng';

  @override
  String get profileFallbackBio => 'Đang sử dụng LumoChat';

  @override
  String get profileSummaryTitle => 'Hồ sơ LumoChat';

  @override
  String get profileSummaryName => 'Tên';

  @override
  String get profileSummaryEmail => 'Email';

  @override
  String get profileSummaryPhone => 'Số điện thoại';

  @override
  String get profileSummaryAddress => 'Địa chỉ';

  @override
  String get profileSummaryCity => 'Thành phố';

  @override
  String get profileSummaryGender => 'Giới tính';

  @override
  String get profileSummaryBirthDate => 'Ngày sinh';

  @override
  String get profileSummaryOccupation => 'Nghề nghiệp';

  @override
  String get profileSummaryWebsite => 'Website';

  @override
  String get profileCopySummarySuccess => 'Đã sao chép thông tin hồ sơ';

  @override
  String get profileStatFriends => 'Bạn bè';

  @override
  String get profileStatGroups => 'Nhóm';

  @override
  String get profileStatStatus => 'Trạng thái';

  @override
  String get profileEdit => 'Chỉnh sửa';

  @override
  String get profileShare => 'Chia sẻ';

  @override
  String get profileSectionBasicInfo => 'Thông tin cơ bản';

  @override
  String get profileFieldPhone => 'Số điện thoại';

  @override
  String get profileFieldAddress => 'Địa chỉ';

  @override
  String get profileFieldCity => 'Thành phố';

  @override
  String get profileFieldGender => 'Giới tính';

  @override
  String get profileFieldBirthDate => 'Ngày sinh';

  @override
  String get profileFieldOccupation => 'Nghề nghiệp';

  @override
  String get profileFieldWebsite => 'Website';

  @override
  String get profileSectionAccount => 'Tài khoản';

  @override
  String get profileMenuPersonalInfo => 'Thông tin cá nhân';

  @override
  String get profileMenuCopyUserId => 'Sao chép ID người dùng';

  @override
  String get profileCopyUserIdSuccess => 'Đã sao chép ID';

  @override
  String get profileMenuSecurity => 'Bảo mật';

  @override
  String get profileSecurityTitle => 'Bảo mật';

  @override
  String get profileSecurityMessage => 'Tính năng bảo mật nâng cao sẽ được cập nhật sớm.';

  @override
  String get profileSectionCustomization => 'Tùy chỉnh';

  @override
  String get profileMenuDarkMode => 'Giao diện tối';

  @override
  String get profileMenuLanguage => 'Ngôn ngữ';

  @override
  String get profileLanguageVietnamese => 'Tiếng Việt';

  @override
  String get profileLanguageEnglish => 'Tiếng Anh';

  @override
  String get profileLanguageDialogTitle => 'Chọn ngôn ngữ';

  @override
  String profileLanguageSaveFailed(String error) {
    return 'Lưu cài đặt ngôn ngữ thất bại: $error';
  }

  @override
  String get profileSectionSupport => 'Hỗ trợ';

  @override
  String get profileMenuHelpCenter => 'Trung tâm hỗ trợ';

  @override
  String get profileHelpTitle => 'Hỗ trợ';

  @override
  String get profileHelpMessage => 'Liên hệ: support@lumochat.app';

  @override
  String get profileMenuReportBug => 'Báo lỗi';

  @override
  String get profileReportBugTitle => 'Báo lỗi';

  @override
  String get profileReportBugMessage => 'Gửi lỗi qua email: bug@lumochat.app';

  @override
  String get profileMenuAbout => 'Giới thiệu';

  @override
  String get profileAboutTitle => 'Giới thiệu';

  @override
  String get profileAboutMessage => 'LumoChat - Kết nối và trò chuyện thời gian thực.';

  @override
  String get profileMenuNotifications => 'Thông báo';

  @override
  String get profileLogout => 'Đăng xuất';

  @override
  String profileLogoutError(String error) {
    return 'Lỗi đăng xuất: $error';
  }

  @override
  String profileSaveSettingFailed(String error) {
    return 'Lưu cài đặt thất bại: $error';
  }

  @override
  String profileVersion(String version) {
    return 'LumoChat v$version';
  }
}
