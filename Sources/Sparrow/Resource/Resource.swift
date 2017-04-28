import HTTP
import Core

public protocol Resource {
    static var parameterKey: ParameterKey { get }
    
    associatedtype ListParameters : ParameterMappable = NoParameters
    associatedtype CreateParameters : ParameterMappable = NoParameters
    associatedtype RemoveAllParameters : ParameterMappable = NoParameters
    associatedtype ShowParameters : ParameterMappable = NoParameters
    associatedtype InsertParameters : ParameterMappable = NoParameters
    associatedtype UpdateParameters : ParameterMappable = NoParameters
    associatedtype RemoveParameters : ParameterMappable = NoParameters
    
    associatedtype CreateInput : ContentMappable = NoContent
    associatedtype InsertInput : ContentMappable = NoContent
    associatedtype UpdateInput : ContentMappable = NoContent
    
    associatedtype ListOutput : ResponseRepresentable = NoContent
    associatedtype CreateOutput : ResponseRepresentable = NoContent
    associatedtype RemoveAllOutput : ResponseRepresentable = NoContent
    associatedtype ShowOutput : ResponseRepresentable = NoContent
    associatedtype InsertOutput : ResponseRepresentable = NoContent
    associatedtype UpdateOutput : ResponseRepresentable = NoContent
    associatedtype RemoveOutput : ResponseRepresentable = NoContent
    
    func configure(collectionRouter: Router, itemRouter: Router)
    
    func preprocess(request: Request) throws
    
    func list(parameters: ListParameters) throws -> ListOutput
    func create(parameters: CreateParameters, content: CreateInput) throws -> CreateOutput
    func removeAll(parameters: RemoveAllParameters) throws -> RemoveAllOutput
    
    func show(parameters: ShowParameters) throws -> ShowOutput
    func insert(parameters: InsertParameters, content: InsertInput) throws -> InsertOutput
    func update(parameters: UpdateParameters, content: UpdateInput) throws -> UpdateOutput
    func remove(parameters: RemoveParameters) throws -> RemoveOutput
    
    func postprocess(response: Response, for request: Request) throws
    
    func recover(error: Error) throws -> Response
}

public extension Resource {
    static var parameterKey: ParameterKey {
        return ParameterKey(String(describing: type(of: self)))
    }
    
    func configure(collectionRouter: Router, itemRouter: Router) {}
    
    func preprocess(request: Request) throws {}
    
    func list(parameters: ListParameters) throws -> ListOutput {
        throw RouterError.methodNotAllowed
    }
    
    func create(parameters: CreateParameters, content: CreateInput) throws -> CreateOutput {
        throw RouterError.methodNotAllowed
    }
    
    func removeAll(parameters: RemoveAllParameters) throws -> RemoveAllOutput {
        throw RouterError.methodNotAllowed
    }
    
    func show(parameters: ShowParameters) throws -> ShowOutput {
        throw RouterError.methodNotAllowed
    }
    
    func insert(parameters: InsertParameters, content: InsertInput) throws -> InsertOutput {
        throw RouterError.methodNotAllowed
    }
    
    func update(parameters: UpdateParameters, content: UpdateInput) throws -> UpdateOutput {
        throw RouterError.methodNotAllowed
    }
    
    func remove(parameters: RemoveParameters) throws -> RemoveOutput {
        throw RouterError.methodNotAllowed
    }
    
    func postprocess(response: Response, for request: Request) throws {}
    
    func recover(error: Error) throws -> Response {
        throw error
    }
}

private func response(from output: ResponseRepresentable, status: HTTPResponse.Status = .ok) -> Response {
    if let output = output as? ContentRepresentable {
        return Response(status: status, content: output.content)
    }
    
    return output.response
}

public extension Resource {
    fileprivate func build(router collectionRouter: Router) {
        collectionRouter.add(Self.parameterKey) { itemRouter in
            configure(collectionRouter: collectionRouter, itemRouter: itemRouter)
            itemRouter.get(body: show(request:))
            itemRouter.put(body: insert(request:))
            itemRouter.patch(body: update(request:))
            itemRouter.delete(body: remove(request:))
        }
        
        collectionRouter.preprocess(body: preprocess(request:))
        
        collectionRouter.get(body: list(request:))
        collectionRouter.post(body: create(request:))
        collectionRouter.delete(body: removeAll(request:))
        
        collectionRouter.postprocess(body: postprocess(response:for:))
        collectionRouter.recover(body: recover(error:))
    }
    
    private func list(request: Request) throws -> Response {
        let parameters = try request.getParameters() as ListParameters
        let output = try self.list(parameters: parameters)
        return response(from: output)
    }
    
    private func create(request: Request) throws -> Response {
        let parameters = try request.getParameters() as CreateParameters
        let input = try request.getContent() as CreateInput
        let output = try self.create(parameters: parameters, content: input)
        return response(from: output, status: .created)
    }
    
    private func removeAll(request: Request) throws -> Response {
        let parameters = try request.getParameters() as RemoveAllParameters
        let output = try self.removeAll(parameters: parameters)
        return response(from: output)
    }
    
    private func show(request: Request) throws -> Response {
        let parameters = try request.getParameters() as ShowParameters
        let output = try show(parameters: parameters)
        return response(from: output)
    }
    
    private func insert(request: Request) throws -> Response {
        let parameters = try request.getParameters() as InsertParameters
        let input = try request.getContent() as InsertInput
        let output = try insert(parameters: parameters, content: input)
        return response(from: output)
    }
    
    private func update(request: Request) throws -> Response {
        let parameters = try request.getParameters() as UpdateParameters
        let input = try request.getContent() as UpdateInput
        let output = try self.update(parameters: parameters, content: input)
        return response(from: output)
    }
    
    private func remove(request: Request) throws -> Response {
        let parameters = try request.getParameters() as RemoveParameters
        let output = try self.remove(parameters: parameters)
        return response(from: output)
    }
}

public extension Router {
    func add<R : Resource>(_ pathComponent: String, resource: R) {
        add(pathComponent, body: resource.build(router:))
    }
}
