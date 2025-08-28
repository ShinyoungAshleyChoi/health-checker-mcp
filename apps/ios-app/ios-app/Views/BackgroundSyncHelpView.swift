import SwiftUI

struct BackgroundSyncHelpView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    helpSection(
                        title: "백그라운드 동기화란?",
                        content: "앱이 백그라운드에서 자동으로 건강 데이터를 서버로 전송하는 기능입니다. iOS 시스템이 적절한 시점에 앱을 실행하여 데이터를 동기화합니다."
                    )
                    
                    helpSection(
                        title: "시뮬레이터 제한사항",
                        content: "iOS 시뮬레이터에서는 실제 백그라운드 작업이 실행되지 않습니다. 실제 기기에서만 정상적으로 동작합니다."
                    )
                    
                    helpSection(
                        title: "설정 확인사항",
                        content: """
                        백그라운드 동기화가 정상 작동하려면:
                        
                        1. 설정 > 일반 > 백그라운드 앱 새로고침이 활성화되어야 함
                        2. 해당 앱의 백그라운드 앱 새로고침이 활성화되어야 함
                        3. 배터리 절약 모드가 비활성화되어야 함
                        4. 앱이 자주 사용되어야 함 (iOS가 우선순위를 결정)
                        """
                    )
                    
                    helpSection(
                        title: "주의사항",
                        content: """
                        • iOS가 백그라운드 작업 실행 시점을 결정합니다
                        • 배터리 상태, 사용 패턴 등에 따라 실행 빈도가 달라집니다
                        • 중요한 데이터는 수동 전송을 권장합니다
                        """
                    )
                }
                .padding()
            }
            .navigationTitle("백그라운드 동기화 도움말")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func helpSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct BackgroundSyncHelpView_Previews: PreviewProvider {
    static var previews: some View {
        BackgroundSyncHelpView()
    }
}
