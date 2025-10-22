# Task Breakdown App Specification (Swift)

## 1. プロダクト概要
- プロダクト名（仮）: Breakdown
- 目的: ユーザーが発生したタスクを素早くメモ登録し、AIを活用して実行可能な作業単位へ自動分割し、完了までの進捗を可視化する。
- ターゲット: 日常業務や学習で複数タスクを抱える個人ユーザー、フリーランス、学生。
- プラットフォーム: iOS 18 以降 (iPhone)、将来的に iPad OS 拡張を見込む。
- 技術スタック: Swift 5.10+, SwiftUI, Combine, Core Data (永続化), WidgetKit (将来的拡張), CloudKit 同期 (第2フェーズ候補)。

## 2. コアユーザーストーリー
1. タスクを思いついた瞬間にタイトルと期限だけメモ登録できる。
2. 後でタスクを開くとAIが推奨する作業分解案を提示し、ユーザーが編集・承認できる。
3. 詳細化済みタスクを日々の実行リストで確認し、完了チェックできる。
4. 完了済みタスクを履歴ページで振り返り、分解ステップの効果をレビューできる。

## 3. ページ構成とナビゲーション
- **ページ1: 詳細化待ち (Inbox)**  
  - 起動時のデフォルト画面。詳細化が未完了のタスク一覧。  
  - 主要アクション: 新規タスク登録ボタン、タスクセルタップでシミュレートポップアップ起動、スワイプで完了/削除。
- **ページ2: 実行中 (Active Work)**  
  - 分解済みタスクの作業ステップをチェックリスト形式で表示。  
  - 作業開始/完了トグル、ステップの所要時間表示、スケジュール提案。
- **ページ3: 完了済み (Completed Archive)**  
  - 完了タスクと付随ステップの履歴表示。検索・フィルタ・シェア。
- **タスクシミュレートポップアップ**  
  - モーダルシートとして表示。  
  - AIが生成した作業ステップ提案、所要時間、推奨順序。ユーザー編集可能。  
  - 承認時にステップがデータモデルへ保存されページ2へ移動。
- **補助要素**: タブバーでページ1〜3を切り替え。ポップアップは `sheet` or `fullScreenCover` で管理。

## 4. 機能要件
### 4.1 タスク登録
- ボタン `+` でシートを開き、タイトル（必須）、期限（任意）、希望作業時間帯（任意、朝/昼/夜プリセット + カスタム時刻）を入力。
- 音声入力 (Speech framework) やクイックスワイプ登録はフェーズ2候補。
- 保存時にタスクは詳細化待ちステータスでページ1に表示。

### 4.2 タスク分割 (AI シミュレーション)
- タスクセルタップでシミュレートポップアップを表示。
- AI提案生成フロー:
  1. ユーザー属性・過去分解履歴を文脈に付与。
  2. OpenAI API (GPT-4.1) もしくは社内LLMへ HTTPS 経由でリクエスト。
  3. レスポンスから候補ステップ（タイトル、説明、推定時間、推奨開始日時）を抽出。
  4. UIでは各ステップを編集可能 (タイトル、所要時間、順序入れ替え)。
- オフライン時はテンプレートベースのローカル分割エンジンを検討。
- 承認時:
  - ステップは `TaskStep` エンティティとして保存。
  - タスクはステータス `refined` に遷移しページ2に移動。

### 4.3 実行管理
- ページ2にてステップ単位のチェックリスト UI。  
  - ステップの状態: `pending`, `in_progress`, `done`。  
  - タップでトグル、長押しでメモ・タイマー起動。  
  - 合計所要時間と今日の予定時間帯に合わせたタイムライン表示。
- 通知: 期限前のリマインド、予定時間帯の開始通知 (UserNotifications)。
- タスク完了条件: 全ステップ `done` or ユーザーがタスク完了を明示的に選択。

### 4.4 完了履歴
- ページ3では完了日順。  
  - メタ情報: 完了日、分解ステップ数、合計実行時間、AI提案 vs ユーザー編集差分。  
  - フィルタ: 期間、タグ（将来拡張）。  
  - エクスポート: CSV / シェアシート (フェーズ2)。

### 4.5 検索・フィルタ
- グローバル検索バーでタイトル・ステップ・メモを全文検索 (Core Data predicates)。
- ステータス、期限、時間帯フィルタ。

### 4.6 設定
- AIサービス APIキー管理、通知設定、テーマ切替 (ライト/ダーク)。
- 使用ガイドリンク、サポート問い合わせ。

### 4.7 コンフリクト度合い計算
- 目的: 同時期に予定されたタスク/ステップがユーザーの可処分時間を超過するリスクを可視化する。
- トリガー: タスク登録・編集時、AI分割承認時、手動で再計算を要求したとき。
- 処理:
  1. 各タスク/ステップの希望時間帯・期限・推定所要時間を時間ブロックに正規化。
  2. 24時間をスロット (例: 30分単位) に分割し、スロットごとに需要合計を算出。
  3. ユーザー設定の可処分時間 (デフォルト: 平日3時間/休日5時間など) と比較し、超過割合をコンフリクト度合いとして算出。
  4. 度合いは0〜100のスコア (0=衝突なし、100=大幅超過) とし、重大度に応じたバッジ/警告を表示。
- UI:
  - ページ1,2のタスクセルにミニゲージ/色付きドットで表示。
  - シミュレートポップアップで提案ステップごとの影響をプレビュー。
- アクション: コンフリクトが高い場合、AIにリスケプラン再提案を依頼するボタン、またはユーザーによる時間帯再設定を促す。

### 4.8 グラフエディタ & 事前LLM分割
- 目的: タスク詳細化を思考マップのように可視化し、LLMが事前生成したサブタスクを高速に編集できる体験を実現する。
- フロー:
  1. タスク登録完了時にLangGraph経由で分割ジョブをバックエンドキューへ投入。citeturn0search0turn0search1
  2. ワーカーがユーザー履歴Embeddingと最新プロンプトテンプレを組み合わせてサブタスク候補を生成。
  3. 結果は`SubtaskNode`/`SubtaskEdge`として保存し、クライアントがグラフエディタで可視化。
  4. ユーザー操作（編集・再生成・昇格）は即時にAPIへ反映し、LangGraph側へフィードバックイベントとして送信。
- 機能:
  - ノード追加・接続、ドラッグ並び替え、Undo/Redo、AI再提案差分プレビュー。
  - 履歴ベース最適化: `UserProfile`に蓄積したembeddingで類似過去タスクからノード候補をレコメンド。citeturn0search2turn0search3
## 5. 非機能要件
- 起動 < 2 秒 (iPhone 14 Pro ベンチマーク)。
- API 応答タイムアウト 10 秒、リトライ 1 回。
- アクセシビリティ: Dynamic Type, VoiceOver ラベル付与。
- データ保持: Core Data + iCloud 同期間隔 1 時間 (任意設定)。
- セキュリティ: APIキーはキーチェーン保管、TLS1.2+必須。

## 6. データモデル設計 (Core Data)
```mermaid
erDiagram
    Task ||--o{ TaskStep : has
    Task ||--o{ SubtaskNode : owns
    SubtaskNode ||--o{ SubtaskEdge : connects
    Task ||--o{ TaskLLMRun : generates
    UserProfile ||--o{ TaskLLMRun : context
    Task {
        UUID id
        String title
        Date createdAt
        Date? dueAt
        String priority // high, medium, low
        String status // draft, refined, completed
        Date? completedAt
        String? aiPromptContext
        Double? conflictScore // 0.0 - 1.0 相対スコア
        Date? conflictCalculatedAt
    }
    TaskStep {
        UUID id
        String title
        String? detail
        Int estimatedMinutes
        Int orderIndex
        String state // pending, in_progress, done
        Date? scheduledAt
        Double? conflictContribution // 衝突スコアへの寄与度
    }
    SubtaskNode {
        UUID id
        UUID taskId
        UUID? parentNodeId
        String title
        String? aiProposedTitle
        Double confidence
        Map metadata // embeddingId, tags
        Int layoutX
        Int layoutY
        Boolean isUserEdited
    }
    SubtaskEdge {
        UUID id
        UUID taskId
        UUID sourceNodeId
        UUID targetNodeId
        String relation // sequence, dependency, blocker
    }
    TaskLLMRun {
        UUID id
        UUID taskId
        Date requestedAt
        Date completedAt
        String modelName
        String status // queued, running, succeeded, failed
        Double latencyMs
        JSON promptSnapshot
        JSON responseSnapshot
    }
    UserProfile {
        UUID id
        JSON embeddingRef
        JSON schedulingPreference // workHours, focusBlocks
        JSON skillSignals // domain proficiency scores
    }
```
- 追加エンティティ候補: `UserProfile`, `NotificationSetting`, `AIModelPreference`。
- `UserProfile`にはユーザーの1日あたり可処分時間や休暇設定、過去タスク履歴のembedding参照などのスケジュール前提を保持。
- `SubtaskNode`はグラフエディタに表示するノード情報とLLM提案の信頼度を保持。`layoutX/Y`はデバイス幅に合わせた正規化座標を保存し、クライアントは再描画時にスケーリングする。
- `TaskLLMRun`はバックグラウンド分割処理のメタデータを保持し、失敗時リトライやA/Bモデル比較に利用する。
- Embeddingメタデータは`pgvector`拡張を利用したPostgreSQLの`vector`カラムに格納し、過去タスクの類似抽出をRAGで行う。citeturn0search2turn0search3

## 7. API インターフェース (暫定)
- `POST /v1/task`  
  - 入力: `title`, `detail?`, `priority`, `dueAt?`, `captureContext?`。  
  - 挙動: 同期レスポンスではタスクIDと暫定メタデータのみ返却。非同期でLLM分割ジョブをキュー投入。
- `POST /v1/task/{id}/graph/rebuild`  
  - 入力: `modelOverride?`, `promptHints?`。  
  - 用途: 手動でサブタスク分割を再実行し、既存ノードにバージョンを付与。
- `GET /v1/task/{id}/graph`  
  - 出力: `nodes[]`, `edges[]`, `layout`, `llmRun`。  
  - オプション: `?includeAudit=true`でLLMラン履歴を付与。
- `PATCH /v1/task/{id}/graph/node/{nodeId}`  
  - 入力: `title`, `metadata`, `status`。  
  - 用途: ユーザー編集内容を保存し`isUserEdited`を更新。
- `POST /v1/task/{id}/graph/reorder`  
  - 入力: `updates[]` (nodeId, orderIndex, layoutX, layoutY)。  
  - 用途: クライアントで編集したノード座標・順序を一括更新。
- `GET /v1/task/{id}/recommendations`  
  - 出力: 類似タスク・テンプレート候補、`confidence`, `explanations`。  
  - データソース: `pgvector` + `TaskLLMRun`ハイライト。
- `POST /v1/task/breakdown` (バックエンド内部フック)  
  - 入力: `taskId`, `promptPayload`, `historyEmbeddingIds`。  
  - 用途: ワーカーがLLM推論後に`SubtaskNode`/`SubtaskEdge`を保存。LangGraphワークフローの終端から呼び出す。citeturn0search0
- SDK 実装: `TaskBreakdownService` (Combine `Future` ベース) に加え、`TaskGraphService`（graphエンドポイント）、`TaskRecommendationService`（履歴パーソナライズ）を提供する。

## 8. UX 詳細仕様
### 8.1 共通UX原則
- SwiftUIを用いた一貫したコンポーネント設計 (`PrimaryButton`, `SecondaryButton`, `CardListCell`)。
- 主要アクションは右下の浮動アクションボタン (FAB) に集約。サブアクションはトレーを使用。
- カラーパレット: Primary(#4C6EF5), Secondary(#ADB5BD), Success(#2F9E44), Alert(#F03E3E), Background(#F8F9FA)。
- ハプティクス: 重要操作承認時は `.success`, エラー時は `.error` を使用。軽微な操作は `.light`。
- Loading/Empty/Errorの各状態で`ProgressView`、アイコン付きメッセージ、リトライボタンを標準化。

### 8.2 ページ1: 詳細化待ち (Inbox)
- レイアウト: `NavigationStack` + `List`、セクションは「期限今日まで」「今週」「期限なし」。
- セル情報: タイトル、期限バッジ、コンフリクトステータスドット、AI提案待ちタグ。
- 空状態: イラスト +「まずはタスクを登録しましょう」CTA。チュートリアルカードを表示。
- 操作:
  - スワイプ右: 完了 (確認ダイアログ付き)。
  - スワイプ左: 削除、アーカイブ (フェーズ2)。
  - 長押し: クイックアクションメニュー（優先度設定、タグ付け）。
- エッジケース: 期限切れタスクは赤ハイライト。コンフリクトスコア80以上は警告トースト。

### 8.3 ページ2: 実行中 (Active Work)
- レイアウト: `ScrollView` + `LazyVStack`、各タスクを`DisclosureGroup`で折り畳み。
- ステップセル: チェックボックス、タイトル、推定時間、進捗チップ (色は状態連動)。
- インタラクション:
  - チェックボックスタップで状態遷移 (`pending`→`in_progress`→`done`)。
  - ステップタップで詳細モーダル (メモ、タイマー開始、担当者割当(将来))。
  - 長押しで並び替えモードに移行。
- タイムライン: 当日予定を水平スクロールで表示し、ステップ配置を視覚化。
- エッジケース: 遅延中(期限過ぎ)ステップはトップにピン留めし、バナー通知。

### 8.4 ページ3: 完了済み (Completed Archive)
- レイアウト: カード型`List`。フィルタバーで期間・タグを切り替え。
- カード内容: 完了日、費やした時間、AI提案との差分 (編集回数)。
- 空状態: バッジ獲得演出と、「完了タスクなし」のメッセージ。
- 操作: カードタップで振り返り画面（ステップ履歴、コメント、再開ボタン）。

### 8.5 グラフエディタ (詳細化ポップアップ)
- レイアウト: フルスクリーン`sheet`内に`Canvas` + `GeometryReader`でノード/エッジを描画。スクロール・ズーム対応 (`MagnificationGesture`, `DragGesture`)。
- 初期状態: ルートタスクノードのみ表示。長押し (`LongPressGesture`) でサブタスク展開パネルを表示し、LLM事前生成ノードをフェードイン。
- ノードUI:
  - カード内にタイトル・信頼度バッジ・編集アイコン。
  - ダブルタップでテキストフィールドを表示し`isUserEdited`を更新。
  - ノードドラッグで`layoutX/Y`を更新。ガイドライン表示で整列を補助。
- エッジUI: `CGPath`で曲線を描画し、ホバー/タップで関係種別（依存・並行）を表示。
- アクションツールバー:
  - `+`ノード追加（空ノード or テンプレートから選択）。
  - 「AI再提案」ボタンで`/graph/rebuild`を呼び出し差分プレビュー。
  - 「タイムラインに送る」操作で選択ノードを`TaskStep`へ昇格。
- 履歴・比較:
  - 右側に`Timeline`表示。LLM提案バージョンとユーザー編集差分をスライド比較。
  - Undo/Redoスタックは`Observable`履歴で最大20アクション保持。
- フィードバック: ノード削除時に理由入力トーストを表示し、バックエンドのフィードバック信号へ送信。
- オフライン時: 展開ボタンを押すとローカルキャッシュの最新バージョンを表示し、接続復旧後に自動同期。

### 8.6 通知・リマインド UX
- 通知カードでアクション:「開始」「スヌーズ30分」「詳細を見る」。
- 通知をタップすると該当ステップ詳細を直接開くディープリンク。
- スヌーズ上限: 3回まで、それ以降は予定再提案を促す。

### 8.7 設定・オンボーディング
- 初回起動: 3枚のチュートリアルカード + デモタスク投入。
- 設定画面: `Form`でAPIキー入力、可処分時間の曜日別スライダー、通知ON/OFF。
- フィードバックセクションでアプリ内メール起動。

### 8.8 アクセシビリティ & ローカリゼーション
- Dynamic Type全サイズ対応、VoiceOverラベル明示、カラーブラインドセーフパレット。
- 日本語を既定とし、英語展開時は`Localizable.strings`管理。右上設定で言語切替。

## 9. ユーザーフロー
### 9.1 ハッピーパス
1. 起動 → ページ1表示 → `+`でタスク登録。
2. 登録直後にバックエンドキューへ分割ジョブ投入（ユーザーには「分割準備中」トースト表示）。
3. タスクセルタップ → グラフエディタがLLM事前生成ノードを読み込み → 編集 → 保存。
3. ページ2でステップを遂行 → 完了チェック。  
4. 全ステップ完了 → 自動的にタスク状態更新 → ページ3へ。  
5. ページ3で履歴確認、必要に応じ再開 (未完了へ戻す機能はフェーズ2)。

### 9.2 エッジケースフロー
- オフライン時: タスク登録はローカル保存のみ。タスク分割はテンプレ提示→オンライン復帰時にAI再依頼。
- AI失敗時: グラフエディタにリトライCTAを表示し、テンプレートからノードを追加。失敗ログは`TaskLLMRun`に保存。
- コンフリクト高スコア時: 警告→「AIに再調整依頼」→ 新たな提案をバージョン差分表示 → ユーザー承認。
- 期限超過: 期限過ぎのタスクは起動時にダイアログ提示。「延長」「完了扱い」「削除」を選択。

### 9.3 サブタスク最適化フロー
1. LLM分割結果保存時に`TaskLLMRun`へ推論メタデータ登録。
2. `UserProfile`へ類似タスクembeddingを更新し、好みの粒度を再学習。
3. ユーザーがノードを編集/削除 → フィードバックキューへイベント送信。
4. バックグラウンドでLangGraphワーカーが次回分割Promptを調整し、`aiPromptContext`に保存。citeturn0search0turn0search2

### 9.3 オンボーディングフロー
1. 初回起動 → タイトル画面で利用目的を選択 (仕事/学習/その他)。
2. チュートリアルカードをスワイプ→サンプルタスク編集→コンフリクトプレビューを体験。
3. 可処分時間入力→通知許可→APIキー設定 (スキップ可)。
4. 実際のInboxへ遷移し、デモタスクが1件登録済み。

## 10. 計測とKPI
- 作業分解完了率 (AI提案承認数 / 登録タスク数)。
- ステップ完了率 (完了ステップ数 / 提案ステップ数)。
- 期限内完了率。
- AI提案編集率 (編集ステップ数 / 提案ステップ数)。
- 平均コンフリクト度合い (計算スコアの移動平均) と高コンフリクトタスクの解消リードタイム。
- グラフ編集指標: ノード確定率 (編集後保存ノード数 / 提案ノード数)、AI再提案採択率、平均ドラッグ操作回数。

## 11. リスクと対策
- **AI品質のばらつき**: フィードバック機構、ユーザーによるステップテンプレ保存。  
- **プライバシー**: API送信データのマスキング、利用規約で明示。  
- **UX複雑化**: 初回オンボーディング、ガイド付きツアー。

## 12. ロードマップ (概略)
1. バージョン0.1: ローカル分解テンプレ + 手動編集、AI未接続。
2. バージョン0.2: 外部AI接続、通知実装。
3. バージョン0.3: iCloud同期、ウィジェット。

## 13. テスト観点
- 単体: ViewModel、AIレスポンスパーサ、Core Dataリポジトリ。
- UI: SwiftUI Snapshotテスト、アクセシビリティラベル検証。
- 結合: APIモックを用いた分解フロー E2E。
- パフォーマンス: 大量タスク (>500) のListスクロール最適化。

## 14. 技術詳細設計
### 14.1 アーキテクチャ概要
- モジュール構成: `App`(SwiftUIエントリ)、`Domain`(UseCase/Entity)、`Data`(Repository/Service)、`Presentation`(View/ViewModel)。
- パターン: MVVM + Clean Architecture。ViewModelはCombine/async awaitハイブリッドで実装。
- 依存関係: `Presentation -> Domain -> Data`。逆向き依存はProtocolで抽象化。
- DI: `Resolver`ライクな軽量コンテナを自作 (EnvironmentValues経由)。

### 14.2 データ永続化
- Core Data Stack: NSPersistentCloudKitContainer (フェーズ2)を見据えて`NSPersistentContainer`で初期実装。`viewContext`(UI用)と`backgroundContext`(同期・AI結果保存)を利用。
- 永続ストア: `sqlite`をアプリサンドボックスに配置。マイグレーションは軽量を想定、バージョン管理は`xcdatamodeld`。
- ローカルキャッシュ: `Task`・`TaskStep`はCore Data。APIレスポンスは`TaskBreakdownCache`（JSON序列化 + Core Data or File Storage）。
- バックアップ: iCloudバックアップ対象。ユーザーオプトアウト可。

### 14.3 ネットワーク & AI連携
- HTTPクライアント: `URLSession` + async/await。リクエストビルダで共通ヘッダー(APIキー、Client-Version)を付与。
- APIキー管理: ユーザー入力をKeychainに保存。ヘッダー`Authorization: Bearer <key>`。
- リトライポリシー: 429/5xxは指数バックオフ (最大3回)。
- レート制限: 1分あたり5リクエスト。キュー管理でバースト抑制。
- プロンプト構成: `TaskContextBuilder`がタイトル、期限、過去履歴、ユーザープロファイルを整形。
- レスポンス解析: JSON Schema検証→`TaskBreakdownDTO`→`TaskStep`へマッピング。

### 14.4 オフライン & 同期
- ネットワーク不可検知: `NWPathMonitor`で状態を監視。オフライン時は`Task.isPendingSync = true`フラグ。
- 後続同期: アプリ起動時・フォアグラウンド復帰時にバックグラウンドキューで未同期タスクを処理。
- コンフリクト解決: サーバーレスポンスとローカル変更が衝突した場合、ユーザーにマージダイアログを提示。

### 14.5 バックグラウンド処理
- `BGAppRefreshTask`で1日2回AI再提案・コンフリクト再計算を実施。
- 通知スケジューリング: `UNUserNotificationCenter`でタスクステップ単位のリクエストを登録。期限変更時はキャンセル→再登録。

### 14.6 CI/CD & 品質管理
- リポジトリ: GitHub。`main`保護。Pull RequestにCI必須。
- CI: GitHub Actions or Xcode Cloud。ジョブ: `swiftlint`, `swift test`, `xcodebuild build-for-testing`, `xcodebuild test-without-building`, UI snapshot diff。
- 配布: TestFlight。`fastlane`でベータ配布・App Storeメタデータ同期。
- セマンティックバージョニング。タグ付けでCIが自動ビルド。

### 14.7 テレメトリ & ログ
- 分析: Firebase AnalyticsまたはAmplitude。イベント: タスク登録、AI承認、コンフリクト警告解消。
- クラッシュ: Sentry or Firebase Crashlytics。fatal以外のエラーは`OSLog`で構造化。
- プライバシー: ユーザーデータは匿名IDで送信。コンテンツテキストは送信しない。

### 14.8 コンフィグ管理
- `Configuration.plist`に環境別設定 (API Base URL、Feature Flags)。
- 環境切替: Debugで`Dev/Staging/Prod`をpicker提供。本番ビルドでは固定。
- Feature Flags: ローカルJSON + リモート設定 (Firebase Remote Configを予定)。

### 14.9 セキュリティ考慮事項
- Keychain保存時は`kSecAttrAccessibleAfterFirstUnlock`。
- クリップボードやスクリーンショットへ敏感情報を表示しない。
- API通信はATS準拠。証明書ピンニングを検討 (フェーズ2)。

### 14.10 LLM分割パイプライン
- オーケストレーション: LangChainのLangGraphを採用し、ノードとして`PromptBuilder`→`Retriever`→`LLMCall`→`Validator`→`Persister`を構成。分岐を用いて失敗時リトライやモデル切替を行う。citeturn0search0
- 実行環境: Python 3.12 + uvで軽量ワーカーを構築。ジョブキューにはRedis StreamsまたはCeleryを利用し、WebフロントからはWebhooks経由で非同期通知を受け取る。citeturn0search1
- モデル選択: デフォルトはGPT-4.1 Turbo (クラウド)、設定でローカル`llama.cpp`ベースモデルに切り替え可能。ローカル時はキャッシュ機構（結果を`TaskLLMRun`に保存）で遅延を抑制。
- バリデーション: `Guardrails`ポリシーでJSON構造をチェックし、ノード数・推定時間の整合性を確認。失敗時はテンプレート分割を返却。

### 14.11 グラフデータ基盤
- ストレージ: Core Data上では`SubtaskNode`/`SubtaskEdge`をミラーリングしつつ、サーバーサイドはPostgreSQL + `pgvector`を採用。ノード構造は`ltree` + JSONBで階層と属性を保持、類似検索は`vector`カラムで実施。citeturn0search2turn0search3
- キャッシュ: Redisにノード一覧をTTL付きでキャッシュし、グラフエディタ初回表示を高速化。
- バージョニング: `graph_version`列を持ち、ユーザーのUndo/RedoやLLM再提案の差分比較に利用。
- スナップショット: 大規模更新時にはS3互換ストレージへ`GraphSnapshot`を吐き出し、復旧/監査に備える。

### 14.12 パーソナライズ & フィードバック
- 埋め込み作成: LangChainの`Embeddings` APIを介してユーザー履歴をベクトル化し、`UserProfile.embeddingRef`で最新の埋め込みIDを保持。RAG再利用の際は`SimilaritySearch`でk近傍タスクを取得。citeturn0search2turn0search3
- シグナル収集: ノード編集・削除・確定などのイベントを`FeedbackEvent`キューに蓄積し、LangGraph内の`Optimizer`ノードが重みづけを更新。
- モデル最適化: 定期バッチで過去N件の`TaskLLMRun`を分析し、モデル選択やプロンプトテンプレを自動調整。フェイルセーフとしてA/Bグループを作成し品質指標 (承認率、編集率) を比較。
