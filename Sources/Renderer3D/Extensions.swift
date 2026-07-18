import Metal
import SharedShaderTypes

public extension UInt32 {
	var mtlColor: MTLClearColor {
		let r = Double(self >> 24 & 0xff) / 255
		let g = Double(self >> 16 & 0xff) / 255
		let b = Double(self >> 8 & 0xff) / 255
		let a = Double(self & 0xff) / 255
		return MTLClearColor(red: r, green: g, blue: b, alpha: a)
	}
	var color: Vec3 {
		let r = Float(self >> 16 & 0xff) / 255
		let g = Float(self >> 8 & 0xff) / 255
		let b = Float(self & 0xff) / 255
		return Vec3(r, g, b)
	}

}

extension Vertex {
	static var defaultLayout: MTLVertexDescriptor {
		let vertexDescriptor = MTLVertexDescriptor()
		vertexDescriptor.attributes[0].format = .float3
		vertexDescriptor.attributes[0].bufferIndex = 0
		vertexDescriptor.attributes[0].offset = 0
		vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
		return vertexDescriptor
	}
}
