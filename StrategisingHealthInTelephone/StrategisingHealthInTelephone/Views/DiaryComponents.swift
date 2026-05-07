//
//  Diary Components.swift
//  StrategisingHealthInTelephone
//
//  Created by Michael Kilvington on 6/5/2026.
//


import SwiftUI

import SwiftUI

struct SwipeableRow<Content: View>: View {
    let content: Content
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var rowHeight: CGFloat = 0
    @State private var isDeleting = false
    
    private let actionWidth: CGFloat = 160
    
    init(onEdit: @escaping () -> Void, onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            content
                .opacity(0)
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear { rowHeight = geo.size.height }
                    }
                )
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    content
                        .frame(width: geometry.size.width)
                    
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.spring()) { offset = 0 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                onEdit()
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Edit")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .frame(width: 80)
                            .frame(maxHeight: .infinity)
                            .background(Color.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            withAnimation(.easeIn(duration: 0.25)) {
                                offset = -geometry.size.width - actionWidth
                                isDeleting = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onDelete()
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Delete")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .frame(width: 80)
                            .frame(maxHeight: .infinity)
                            .background(Color.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: actionWidth)
                }
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            guard !isDeleting else { return }
                            let drag = value.translation.width
                            if drag < 0 {
                                offset = max(-actionWidth, drag)
                            } else if offset < 0 {
                                offset = min(0, -actionWidth + drag)
                            }
                        }
                        .onEnded { value in
                            guard !isDeleting else { return }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = value.translation.width < -40 ? -actionWidth : 0
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture().onEnded {
                        guard !isDeleting else { return }
                        if offset < 0 {
                            withAnimation(.spring()) { offset = 0 }
                        }
                    }
                )
            }
            .frame(height: rowHeight)
            .clipped()
        }
        .frame(height: rowHeight)
        .frame(height: isDeleting ? 0 : rowHeight)
        .opacity(isDeleting ? 0 : 1)
        .animation(.easeIn(duration: 0.25).delay(0.15), value: isDeleting)
        .clipped()
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
                ConnectedGlassCard(corners: [.bottomLeft, .bottomRight]) {
                    Text("No items added")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
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

struct ServingControl: View {
    @Binding var servings: Double
    @GestureState private var dragOffset: CGFloat = 0
    @State private var baseServings: Double = 1.0
    
    private let minServings: Double = 0.1
    private let maxServings: Double = 10.0
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                servings = max(minServings, (servings - 0.1).rounded(toPlaces: 1))
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        let delta = -value.translation.height / 50
                        let newValue = (baseServings + delta).rounded(toPlaces: 1)
                        servings = min(maxServings, max(minServings, newValue))
                    }
                    .onEnded { _ in
                        baseServings = servings
                    }
            )
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(String(format: "%.1f", servings))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text("servings")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 80)
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        let delta = -value.translation.height / 50
                        let newValue = (baseServings + delta).rounded(toPlaces: 1)
                        servings = min(maxServings, max(minServings, newValue))
                    }
                    .onEnded { _ in
                        baseServings = servings
                    }
            )
            
            Spacer()
            
            Button(action: {
                servings = min(maxServings, (servings + 0.1).rounded(toPlaces: 1))
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        let delta = -value.translation.height / 50
                        let newValue = (baseServings + delta).rounded(toPlaces: 1)
                        servings = min(maxServings, max(minServings, newValue))
                    }
                    .onEnded { _ in
                        baseServings = servings
                    }
            )
        }
        .padding(.vertical, 4)
        .onAppear {
            baseServings = servings
        }
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

