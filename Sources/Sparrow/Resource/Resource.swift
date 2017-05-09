import HTTP
import Core

public protocol Resource {
    static var idKey: ParameterKey { get }
    
    associatedtype ListParameters : ParametersInitializable = NoParameters
    associatedtype CreateParameters : ParametersInitializable = NoParameters
    associatedtype RemoveAllParameters : ParametersInitializable = NoParameters
    associatedtype ShowParameters : ParametersInitializable = NoParameters
    associatedtype InsertParameters : ParametersInitializable = NoParameters
    associatedtype UpdateParameters : ParametersInitializable = NoParameters
    associatedtype RemoveParameters : ParametersInitializable = NoParameters
    
    associatedtype CreateInput : ContentInitializable = NoContent
    associatedtype InsertInput : ContentInitializable = NoContent
    associatedtype UpdateInput : ContentInitializable = NoContent
    
    associatedtype ListOutput : ResponseRepresentable = NoContent
    associatedtype CreateOutput : ResponseRepresentable = NoContent
    associatedtype RemoveAllOutput : ResponseRepresentable = NoContent
    associatedtype ShowOutput : ResponseRepresentable = NoContent
    associatedtype InsertOutput : ResponseRepresentable = NoContent
    associatedtype UpdateOutput : ResponseRepresentable = NoContent
    associatedtype RemoveOutput : ResponseRepresentable = NoContent
    
    func configure(collectionRouter: Router, itemRouter: Router)
    
    func preprocess(request: Request) throws
    
    func list(request: Request, parameters: ListParameters) throws -> ListOutput
    func create(request: Request, parameters: CreateParameters, content: CreateInput) throws -> CreateOutput
    func removeAll(request: Request, parameters: RemoveAllParameters) throws -> RemoveAllOutput
    
    func show(request: Request, parameters: ShowParameters) throws -> ShowOutput
    func insert(request: Request, parameters: InsertParameters, content: InsertInput) throws -> InsertOutput
    func update(request: Request, parameters: UpdateParameters, content: UpdateInput) throws -> UpdateOutput
    func remove(request: Request, parameters: RemoveParameters) throws -> RemoveOutput
    
    func postprocess(response: Response, for request: Request) throws
    
    func recover(error: Error) throws -> Response
}

public extension Resource {
    static var idKey: ParameterKey {
        return ParameterKey(String(describing: type(of: self)))
    }
    
    func configure(collectionRouter: Router, itemRouter: Router) {}
    
    func preprocess(request: Request) throws {}
    
    func list(request: Request, parameters: ListParameters) throws -> ListOutput {
        throw RouterError.methodNotAllowed
    }
    
    func create(request: Request, parameters: CreateParameters, content: CreateInput) throws -> CreateOutput {
        throw RouterError.methodNotAllowed
    }
    
    func removeAll(request: Request, parameters: RemoveAllParameters) throws -> RemoveAllOutput {
        throw RouterError.methodNotAllowed
    }
    
    func show(request: Request, parameters: ShowParameters) throws -> ShowOutput {
        throw RouterError.methodNotAllowed
    }
    
    func insert(request: Request, parameters: InsertParameters, content: InsertInput) throws -> InsertOutput {
        throw RouterError.methodNotAllowed
    }
    
    func update(request: Request, parameters: UpdateParameters, content: UpdateInput) throws -> UpdateOutput {
        throw RouterError.methodNotAllowed
    }
    
    func remove(request: Request, parameters: RemoveParameters) throws -> RemoveOutput {
        throw RouterError.methodNotAllowed
    }
    
    func postprocess(response: Response, for request: Request) throws {}
    
    func recover(error: Error) throws -> Response {
        throw error
    }
}

private func response(from output: ResponseRepresentable, status: Status = .ok) -> Response {
    if let output = output as? ContentRepresentable {
        return Response(status: status, content: output.content)
    }
    
    return output.response
}

public extension Resource {
    fileprivate func build(router collectionRouter: Router) {
        collectionRouter.add(parameter: Self.idKey) { itemRouter in
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
        let output = try self.list(request: request, parameters: parameters)
        return response(from: output)
    }
    
    private func create(request: Request) throws -> Response {
        let parameters = try request.getParameters() as CreateParameters
        let input = try request.getContent() as CreateInput
        let output = try self.create(request: request, parameters: parameters, content: input)
        return response(from: output, status: .created)
    }
    
    private func removeAll(request: Request) throws -> Response {
        let parameters = try request.getParameters() as RemoveAllParameters
        let output = try self.removeAll(request: request, parameters: parameters)
        return response(from: output)
    }
    
    private func show(request: Request) throws -> Response {
        let parameters = try request.getParameters() as ShowParameters
        let output = try show(request: request, parameters: parameters)
        return response(from: output)
    }
    
    private func insert(request: Request) throws -> Response {
        let parameters = try request.getParameters() as InsertParameters
        let input = try request.getContent() as InsertInput
        let output = try insert(request: request, parameters: parameters, content: input)
        return response(from: output)
    }
    
    private func update(request: Request) throws -> Response {
        let parameters = try request.getParameters() as UpdateParameters
        let input = try request.getContent() as UpdateInput
        let output = try self.update(request: request, parameters: parameters, content: input)
        return response(from: output)
    }
    
    private func remove(request: Request) throws -> Response {
        let parameters = try request.getParameters() as RemoveParameters
        let output = try self.remove(request: request, parameters: parameters)
        return response(from: output)
    }
}

public extension Router {
    func add<R : Resource>(path: String, resource: R) {
        add(path: path, body: resource.build(router:))
    }
}
