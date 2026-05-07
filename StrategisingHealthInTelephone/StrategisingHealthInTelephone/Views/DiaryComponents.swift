//
//  Diary Components.swift
//  StrategisingHealthInTelephone
//
//  Created by Michael Kilvington on 6/5/2026.
//


import SwiftUI

struct SwipeableRow<Content: View>: View {
    let content: Content
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var showingActions = false
    
    private let actionWidth: CGFloat = 160  // Total width of both action buttons
    private let editWidth: CGFloat = 80
    private let deleteWidth: CGFloat = 80
    
    init(onEdit: @escaping () -> Void, onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // ✅ Action buttons revealed by swipe
            HStack(spacing: 0) {
                // Edit button
                Button(action: {
                    withAnimation(.spring()) {
                        offset = 0
                        showingActions = false
                    }
                    onEdit()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .medium))
                        Text("Edit")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .frame(width: editWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.blue)
                }
                
                // Delete button
                Button(action: {
                    withAnimation(.spring()) {
                        offset = 0
                        showingActions = false
                    }
                    onDelete()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                        Text("Delete")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .frame(width: deleteWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 0))  // Actions sit behind content
            .opacity(showingActions ? 1 : 0)
            
            // ✅ Main content — slides left to reveal actions
            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onChanged { value in
                            // Only allow left swipe
                            guard value.translation.width < 0 else {
                                if showingActions {
                                    offset = max(-actionWidth, value.translation.width - actionWidth)
                                }
                                return
                            }
                            if showingActions {
                                offset = max(-actionWidth, -actionWidth + value.translation.width)
                            } else {
                                offset = max(-actionWidth, value.translation.width)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if value.translation.width < -40 {
                                    offset = -actionWidth
                                    showingActions = true
                                } else {
                                    offset = 0
                                    showingActions = false
                                }
                            }
                        }
                )
        }
        .clipped()
        // ✅ Tap anywhere on content when actions are showing closes them
        .onTapGesture {
            if showingActions {
                withAnimation(.spring()) {
                    offset = 0
                    showingActions = false
                }
            }
        }
    }
}

struct ConnectedGlassCard<Content: View>: View {
    @EnvironmentObject var appTheme: AppTheme
    let corners: UIRectCorner
    let content: Content
    
    init(corners: UIRectCorner = .allCorners, @ViewBuilder content: () -> Content) {
        self.corners = corners
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(appTheme.cardMaterial)
            .clipShape(RoundedCorner(radius: 14, corners: corners))
            .overlay(
                RoundedCorner(radius: 14, corners: corners)
                    .stroke(appTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: appTheme.shadowColor, radius: 10, y: 4)
    }
}

// ✅ Shape that lets us round only specific corners
struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct ConnectedRowBackground: View {
    @EnvironmentObject var appTheme: AppTheme
    let corners: UIRectCorner
    
    var body: some View {
        ZStack {
            RoundedCorner(radius: 14, corners: corners)
                .fill(appTheme.cardMaterial)
            RoundedCorner(radius: 14, corners: corners)
                .stroke(appTheme.cardStroke, lineWidth: 1)
        }
        .padding(.horizontal, -2)
    }
}

// ✅ Self-contained meal section with connected glass styling and swipe actions
struct DiaryMealSection: View {
    @EnvironmentObject var appTheme: AppTheme
    let mealType: MealType
    let meal: Meal?
    let log: DailyLog
    let onAddFood: () -> Void
    let onEditFood: (FoodItem) -> Void
    let onDeleteFood: (FoodItem) -> Void
    
    var foodItems: [FoodItem] { meal?.foodItems ?? [] }
    
    var body: some View {
        VStack(spacing: 0) {
            // ✅ Header — rounded top only
            ConnectedGlassCard(corners: [.topLeft, .topRight]) {
                HStack {
                    Text(mealType.rawValue)
                        .font(.headline)
                    Spacer()
                    if let meal = meal {
                        Text("\(Int(meal.totalCalories)) kcal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Button(action: onAddFood) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if foodItems.isEmpty {
                // ✅ Empty state — rounded bottom only
                ConnectedGlassCard(corners: [.bottomLeft, .bottomRight]) {
                    Text("No items added")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                // ✅ Each food item — no rounding except last item
                ForEach(Array(foodItems.enumerated()), id: \.element.id) { index, food in
                    let isLast = index == foodItems.count - 1
                    let corners: UIRectCorner = isLast ? [.bottomLeft, .bottomRight] : []
                    
                    ConnectedGlassCard(corners: corners) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(food.name)
                                    .font(.subheadline)
                                Text("\(Int(food.calories)) kcal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    // ✅ Swipe actions on each item card
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            onDeleteFood(food)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            onEditFood(food)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
    }
}

