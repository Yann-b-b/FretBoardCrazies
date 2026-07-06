import SwiftUI

struct InstrumentPicker: View {
    @Binding var selectedId: String

    var body: some View {
        HStack(spacing: 28) {
            ForEach(Instruments.all, id: \.id) { instrument in
                let isSelected = instrument.id == selectedId
                Button {
                    selectedId = instrument.id
                } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 16, height: 16)
                        Text(instrument.name)
                            .font(.caption)
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(instrument.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
