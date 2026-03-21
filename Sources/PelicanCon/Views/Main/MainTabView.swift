import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var notificationService: NotificationService

    @StateObject private var eventVM     = EventViewModel()
    @StateObject private var chatVM      = ChatViewModel()
    @StateObject private var galleryVM   = GalleryViewModel()
    @StateObject private var directoryVM = DirectoryViewModel()
    @StateObject private var profileVM   = ProfileViewModel()

    @State private var selectedTab = 0

    private var currentUser: AppUser? { authVM.currentUser }

    var body: some View {
        TabView(selection: $selectedTab) {
            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(0)
                .environmentObject(eventVM)

            ChatListView()
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
                .badge(chatVM.totalUnreadDMs())
                .tag(1)
                .environmentObject(chatVM)

            GalleryView()
                .tabItem {
                    Label("Photos", systemImage: "photo.stack.fill")
                }
                .tag(2)
                .environmentObject(galleryVM)

            DirectoryView()
                .tabItem {
                    Label("Directory", systemImage: "person.2.fill")
                }
                .tag(3)
                .environmentObject(directoryVM)
                .environmentObject(chatVM)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(4)
                .environmentObject(profileVM)
        }
        .tint(Theme.red)
        .onAppear {
            setupViewModels()
            startAllListeners()
        }
        .onChange(of: notificationService.deepLinkTarget) { _, target in
            handleDeepLink(target)
        }
    }

    private func setupViewModels() {
        guard let user = currentUser, let uid = user.id else { return }

        eventVM.userId        = uid
        chatVM.currentUserId  = uid
        chatVM.currentUserName  = user.displayName
        chatVM.currentUserPhoto = user.profilePhotoURL
        galleryVM.currentUserId   = uid
        galleryVM.currentUserName  = user.displayName
        galleryVM.currentUserPhoto = user.profilePhotoURL
    }

    private func startAllListeners() {
        guard let uid = currentUser?.id else { return }

        eventVM.startListening()
        chatVM.startGroupChatListener()
        chatVM.startDMListListener(userId: uid)
        galleryVM.startListening()
        directoryVM.startListening()
        profileVM.startListening(userId: uid)
    }

    private func handleDeepLink(_ target: DeepLinkTarget?) {
        switch target {
        case .conversation: selectedTab = 1
        case .photo:        selectedTab = 2
        case .event:        selectedTab = 0
        case .none:         break
        }
    }
}
