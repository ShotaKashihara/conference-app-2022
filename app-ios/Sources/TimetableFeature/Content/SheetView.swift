import SwiftUI
import Theme
import Model
import ComposableArchitecture

struct TimetableSheetView: View {
    struct ViewState: Equatable {
        var roomTimetableItems: [TimetableRoomItems]
        var hours: [Int]

        init(state: TimetableState) {
            guard let timetable = state.dayToTimetable[state.selectedDay] else {
                self.roomTimetableItems = []
                self.hours = []
                return
            }
            self.hours = timetable.hours
            self.roomTimetableItems = Set(timetable.timetableItems.map(\.room))
                .map { room in
                    var items = timetable.contents
                        .filter { itemWithFavorite in
                            itemWithFavorite.timetableItem.room == room
                        }
                        .reduce([TimetableItemType]()) { result, item in
                            var result = result
                            let lastItem = result.last
                            if case .general(let lItem, _) = lastItem, lItem.timetableItem.endsAt != item.timetableItem.startsAt {
                                result.append(.spacing(calculateMinute(
                                    startSeconds: Int(lItem.timetableItem.endsAt.epochSeconds),
                                    endSeconds: Int(item.timetableItem.startsAt.epochSeconds)
                                )))
                            }
                            let minute = calculateMinute(
                                startSeconds: Int(item.timetableItem.startsAt.epochSeconds),
                                endSeconds: Int(item.timetableItem.endsAt.epochSeconds)
                            )
                            result.append(
                                TimetableItemType.general(
                                    item,
                                    minute
                                )
                            )

                            return result
                        }
                    if case let .general(firstItem, _) = items.first {
                        let hour = Calendar.current.component(.hour, from: firstItem.timetableItem.startsAt.toDate())
                        let minute = Calendar.current.component(.minute, from: firstItem.timetableItem.startsAt.toDate())
                        let firstSpacingItem: TimetableItemType = .spacing(minute + max(hour - timetable.hours.first!, 0) * 60)
                        items.insert(firstSpacingItem, at: 0)
                    }
                    return TimetableRoomItems(
                        room: room,
                        items: items
                    )
                }
                .sorted {
                    $0.room.sort < $1.room.sort
                }
        }
    }

    private static let minuteHeight: CGFloat = 4
    private static let timetableStartTime: DateComponents = .init(hour: 10, minute: 0)
    private let dateComponentsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        return formatter
    }()

    let store: Store<TimetableState, TimetableAction>

    var body: some View {
        WithViewStore(store.scope(state: ViewState.init)) { viewStore in
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    Spacer()
                        .frame(width: 16)
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 34)
                        ForEach(viewStore.hours, id: \.self) { hour in
                            Text(dateComponentsFormatter.string(from: DateComponents(hour: hour, minute: 0))!)
                                .font(Font.system(size: 16, weight: .bold, design: .default))
                                .frame(
                                    height: TimetableSheetView.minuteHeight * 60,
                                    alignment: .top
                                )
                        }
                    }
                    Spacer()
                        .frame(width: 16)
                    Divider()
                        .foregroundColor(AssetColors.surfaceVariant.swiftUIColor)
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(viewStore.roomTimetableItems, id: \.room) { timetableRoomItems in
                                let room = timetableRoomItems.room
                                let timetableItems = timetableRoomItems.items
                                VStack(spacing: 0) {
                                    Text(room.name.jaTitle)
                                        .font(Font.system(size: 14, weight: .bold, design: .default))
                                        .padding(.top, 8)
                                        .padding(.bottom, 16)
                                    Divider()
                                        .foregroundColor(AssetColors.surfaceVariant.swiftUIColor)
                                    ForEach(timetableItems) { item in
                                        if case let .general(item, minutes) = item {
                                            TimetableItemView(item: item)
                                                .frame(height: CGFloat(minutes) * TimetableSheetView.minuteHeight)
                                        } else if case let .spacing(minutes) = item {
                                            Spacer()
                                                .frame(maxHeight: CGFloat(minutes) * TimetableSheetView.minuteHeight)
                                        }
                                    }
                                }
                                .frame(width: 192)
                                Divider()
                                    .foregroundColor(AssetColors.surfaceVariant.swiftUIColor)
                            }
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
struct TimetableSheetView_Previews: PreviewProvider {
    static var previews: some View {
        TimetableSheetView(
            store: .init(
                initialState: .init(
                    dayToTimetable: DroidKaigiSchedule.companion.fake().dayToTimetable
                ),
                reducer: .empty,
                environment: TimetableEnvironment(
                    sessionsRepository: FakeSessionsRepository()
                )
            )
        )
    }
}
#endif
