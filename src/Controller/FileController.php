<?php

declare(strict_types=1);

namespace Rarst\ReleaseBelt\Controller;

use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Log\LoggerInterface;
use Rarst\ReleaseBelt\Model\FileModel;
use Rarst\ReleaseBelt\Release;
use Slim\Exception\HttpNotFoundException;
use Slim\Http\Response;
use Slim\Psr7\Stream;
use Symfony\Component\Finder\SplFileInfo;

/**
 * Handles the route for file downloads.
 */
class FileController
{
    protected FileModel $model;

    public function __construct(FileModel $model)
    {
        $this->model  = $model;
    }

    /**
     * Looks up the file and sends download response.
     *
     * @throws HttpNotFoundException
     */
    public function __invoke(Request $request, Response $response, string $vendor, string $file): Response
    {
        $sendFile = $this->model->getFile($vendor, $file);

        if (! $sendFile->isReadable()) {
            throw new HttpNotFoundException($request);
        }

        if (strtolower(substr($sendFile->getPathname(), 0, 5)) === 's3://') {
            /*
             * The regex used below is to ensure that the $fileName contains only
             * characters ranging from ASCII 128-255 and ASCII 0-31 and 127 are replaced with an empty string
             */
            $disposition = 'attachment; filename="'.
                preg_replace('/[\x00-\x1F\x7F\"]/', ' ', $sendFile->getFilename()).
                '"';
            $disposition .= "; filename*=UTF-8''".rawurlencode($sendFile->getFilename());

            $context = stream_context_create(['s3' => ['seekable' => true]]);
            return $response->withBody(new Stream(fopen($sendFile->getPathname(), 'r', false, $context)))
                            ->withHeader('Content-Disposition', $disposition);
        }
        return $response->withFileDownload($sendFile->getRealPath());

    }
}
